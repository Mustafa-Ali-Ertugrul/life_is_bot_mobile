import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


TOL = 75
TARGET = (297, 503)
PAD = 6
FRAME_MS = 60
ERODE_PX = 1
OUTPUT_FRAME_COUNT = 60


def cartoon_mask(frame):
    height, width = frame.shape[:2]
    flood_mask = np.zeros((height + 2, width + 2), dtype=np.uint8)
    tolerance = (TOL, TOL, TOL)
    seeds = (
        [(x, 0) for x in range(0, width, 4)]
        + [(x, height - 1) for x in range(0, width, 4)]
        + [(0, y) for y in range(0, height, 4)]
        + [(width - 1, y) for y in range(0, height, 4)]
    )
    work = frame.copy()
    for seed_x, seed_y in seeds:
        if flood_mask[seed_y + 1, seed_x + 1] & 1:
            continue
        cv2.floodFill(
            work,
            flood_mask,
            (seed_x, seed_y),
            0,
            loDiff=tolerance,
            upDiff=tolerance,
            flags=8 | cv2.FLOODFILL_MASK_ONLY | cv2.FLOODFILL_FIXED_RANGE,
        )

    subject = (flood_mask[1:-1, 1:-1] == 0).astype(np.uint8)
    subject = cv2.morphologyEx(
        subject,
        cv2.MORPH_CLOSE,
        np.ones((7, 7), np.uint8),
    )
    component_count, labels, stats, _ = cv2.connectedComponentsWithStats(
        subject,
        8,
    )
    if component_count <= 1:
        return None

    person_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    person = labels == person_label
    inverse = (~person).astype(np.uint8)
    hole_count, hole_labels, hole_stats, _ = cv2.connectedComponentsWithStats(
        inverse,
        4,
    )
    border_labels = (
        set(hole_labels[0, :])
        | set(hole_labels[-1, :])
        | set(hole_labels[:, 0])
        | set(hole_labels[:, -1])
    )
    person_y, _ = np.nonzero(person)
    if len(person_y):
        person_bottom = person_y.max()
        for label in range(1, hole_count):
            if label in border_labels:
                continue
            area = int(hole_stats[label, cv2.CC_STAT_AREA])
            if area < 300:
                continue
            hole = hole_labels == label
            hole_y, hole_x = np.nonzero(hole)
            if hole_y.max() > person_bottom - 40:
                continue
            patch = frame[hole_y, hole_x]
            if (patch > 225).all(axis=1).mean() > 0.80:
                person[hole] = False

    if ERODE_PX:
        kernel_size = 1 + 2 * ERODE_PX
        person = cv2.erode(
            person.astype(np.uint8),
            np.ones((kernel_size, kernel_size), np.uint8),
        ).astype(bool)
    return person


def nearest_fill(rgb, person):
    if not person.any():
        return rgb.copy()
    inverse = (~person).astype(np.uint8)
    _, labels = cv2.distanceTransformWithLabels(
        inverse,
        cv2.DIST_L2,
        5,
        labelType=cv2.DIST_LABEL_PIXEL,
    )
    person_y, person_x = np.nonzero(person)
    colors = rgb[person_y, person_x]
    height, width = person.shape
    flat_labels = np.clip((labels - 1).reshape(-1), 0, len(colors) - 1)
    return colors[flat_labels].reshape(height, width, 3)


def recolor_green(rgb):
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.int16)
    saturated = hsv[..., 1] > 60
    hsv[..., 0] = np.where(saturated, (hsv[..., 0] - 22) % 180, hsv[..., 0])
    return cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)


def remove_internal_white(canvas):
    alpha = canvas[..., 3] > 0
    opaque_y, _ = np.nonzero(alpha)
    if not len(opaque_y):
        return canvas
    hsv = cv2.cvtColor(canvas[..., :3], cv2.COLOR_RGB2HSV)
    rows = np.arange(canvas.shape[0])[:, None]
    shoe_top = int(opaque_y.max()) - 80
    white_like = alpha & (hsv[..., 1] < 90) & (hsv[..., 2] > 120)
    canvas[white_like & (rows < shoe_top), 3] = 0
    return canvas


def read_frames(source):
    video = cv2.VideoCapture(str(source))
    if not video.isOpened():
        raise RuntimeError(f"Video açılamadı: {source}")
    fps = video.get(cv2.CAP_PROP_FPS)
    if fps <= 0:
        video.release()
        raise RuntimeError(f"Video kare hızı okunamadı: {source}")
    frames = []
    while True:
        ok, frame = video.read()
        if not ok:
            break
        frames.append(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    video.release()
    if not frames:
        raise RuntimeError(f"Videoda kare bulunamadı: {source}")
    return frames, fps


def resample_phase(phase):
    if len(phase) == OUTPUT_FRAME_COUNT:
        return phase
    indices = np.linspace(0, len(phase) - 1, OUTPUT_FRAME_COUNT)
    return [phase[round(index)] for index in indices]


def render_phase(phase, phase_number, output_dir):
    masks = []
    boxes = []
    for frame_number, frame in enumerate(phase, start=1):
        mask = cartoon_mask(frame)
        if mask is None or not mask.any():
            raise RuntimeError(
                f"Faz {phase_number}, kare {frame_number}: figür bulunamadı"
            )
        masks.append(mask)
        y, x = np.nonzero(mask)
        boxes.append((int(x.min()), int(y.min()), int(x.max()), int(y.max())))

    x_min = min(box[0] for box in boxes)
    y_min = min(box[1] for box in boxes)
    x_max = max(box[2] for box in boxes)
    y_max = max(box[3] for box in boxes)
    box_width = x_max - x_min + 1
    box_height = y_max - y_min + 1
    scale = min(
        (TARGET[1] - 2 * PAD) / box_height,
        (TARGET[0] - 2 * PAD) / box_width,
    )
    scaled_width = max(1, round(box_width * scale))
    scaled_height = max(1, round(box_height * scale))
    offset_x = (TARGET[0] - scaled_width) // 2

    output_frames = []
    for frame, mask in zip(phase, masks):
        region = frame[y_min : y_min + box_height, x_min : x_min + box_width]
        region_mask = mask[
            y_min : y_min + box_height,
            x_min : x_min + box_width,
        ]
        filled = nearest_fill(region, region_mask)
        scaled_rgb = cv2.resize(
            filled,
            (scaled_width, scaled_height),
            interpolation=cv2.INTER_AREA,
        )
        scaled_mask = (
            cv2.resize(
                region_mask.astype(np.uint8),
                (scaled_width, scaled_height),
                interpolation=cv2.INTER_NEAREST,
            )
            > 0
        )
        scaled_rgb = recolor_green(scaled_rgb)
        canvas = np.zeros((TARGET[1], TARGET[0], 4), dtype=np.uint8)
        opaque_y, _ = np.nonzero(scaled_mask)
        if len(opaque_y):
            row_top = int(opaque_y.min())
            row_bottom = int(opaque_y.max()) + 1
            subject_rgb = scaled_rgb[row_top:row_bottom]
            subject_mask = scaled_mask[row_top:row_bottom]
            offset_y = TARGET[1] - PAD - subject_rgb.shape[0]
            if offset_y < 0:
                subject_rgb = subject_rgb[-offset_y:]
                subject_mask = subject_mask[-offset_y:]
                offset_y = 0
            subject_height = subject_rgb.shape[0]
            canvas[
                offset_y : offset_y + subject_height,
                offset_x : offset_x + scaled_width,
                :3,
            ] = subject_rgb
            canvas[
                offset_y : offset_y + subject_height,
                offset_x : offset_x + scaled_width,
                3,
            ] = subject_mask * 255
        output_frames.append(Image.fromarray(remove_internal_white(canvas)))

    output_path = output_dir / f"routine_female_phase_{phase_number}.gif"
    output_frames[0].save(
        output_path,
        save_all=True,
        append_images=output_frames[1:],
        duration=FRAME_MS,
        loop=0,
        transparency=0,
        optimize=False,
        disposal=2,
    )
    print(
        f"Faz {phase_number}: {box_width}x{box_height}, "
        f"ölçek {scale:.2f} -> {output_path}"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_mp4", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--end-seconds", type=float)
    arguments = parser.parse_args()
    output_dir = arguments.output_dir or (
        Path(__file__).resolve().parent.parent / "assets" / "images"
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    frames, fps = read_frames(arguments.source_mp4)
    if arguments.end_seconds is not None:
        if arguments.end_seconds <= 0:
            raise RuntimeError("Bitiş süresi sıfırdan büyük olmalı")
        frames = frames[: round(arguments.end_seconds * fps)]
        if not frames:
            raise RuntimeError("Seçilen süre aralığında kare bulunamadı")
    frame_count = len(frames)
    bounds = [round(frame_count * index / 4) for index in range(5)]
    for phase_index in range(4):
        phase = frames[bounds[phase_index] : bounds[phase_index + 1]]
        if not phase:
            raise RuntimeError(f"Faz {phase_index + 1} boş")
        render_phase(resample_phase(phase), phase_index + 1, output_dir)


if __name__ == "__main__":
    main()
