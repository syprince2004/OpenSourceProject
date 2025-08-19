from fastapi import FastAPI, UploadFile, File
from ultralytics import YOLO
from torch.serialization import add_safe_globals
from torch.nn.modules.conv import Conv2d
from torch.nn.modules.container import Sequential, ModuleList
from torch.nn.modules.batchnorm import BatchNorm2d
from torch.nn.modules.activation import SiLU
from ultralytics.nn.tasks import DetectionModel
import ultralytics.nn.modules.conv as ultralytics_conv
import ultralytics.nn.modules.block as ultralytics_block
import ultralytics.nn.modules.head as ultralytics_head
from torch.nn.modules.pooling import MaxPool2d
from torch.nn.modules.upsampling import Upsample
import numpy as np
import cv2
import logging
from fastapi import FastAPI, Request
from pydantic import BaseModel
import base64
import io
from PIL import Image

add_safe_globals([
    Conv2d,
    DetectionModel,
    Sequential,
    ModuleList,
    ultralytics_conv.Conv,
    ultralytics_conv.Concat,
    BatchNorm2d,
    SiLU,
    ultralytics_block.C2f,
    ultralytics_block.Bottleneck,
    ultralytics_block.SPPF,
    ultralytics_head.Detect,
    ultralytics_block.DFL,
    MaxPool2d,
    Upsample,
])

app = FastAPI()

class ImageData(BaseModel):
    image: str

model = YOLO("best.pt")

logging.basicConfig(level=logging.INFO)

@app.post("/detect")
async def detect(file: UploadFile = File(...)):
    logging.info(f"Received file: {file.filename}")
    contents = await file.read()
    nparr = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if image is None:
        logging.error("Failed to decode image")
        return {"error": "Invalid image"}

    results = model.predict(source=image, conf=0.25, verbose=False)
    detections = []

    for result in results:
        boxes = result.boxes.xyxy.cpu().numpy()
        classes = result.boxes.cls.cpu().numpy()
        confidences = result.boxes.conf.cpu().numpy()
        for box, cls, conf in zip(boxes, classes, confidences):
            detections.append({
                "box": box.tolist(),
                "class": int(cls),
                "confidence": float(conf)
            })

    logging.info(f"Detections: {detections}")
    return {"detections": detections}

@app.post("/upload")
async def upload_image(data: ImageData):
    image_bytes = base64.b64decode(data.image)
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    image_np = np.array(image)

    results = model.predict(source=image_np, conf=0.25, verbose=False)
    detections = []

    for result in results:
        boxes = result.boxes.xyxy.cpu().numpy()
        classes = result.boxes.cls.cpu().numpy()
        confidences = result.boxes.conf.cpu().numpy()
        for box, cls, conf in zip(boxes, classes, confidences):
            detections.append({
                "box": [round(coord, 2) for coord in box.tolist()],
                "class": int(cls),
                "label": model.names[int(cls)],
                "confidence": round(float(conf), 2)
            })

    return {"message": "객체 탐지 완료", "detections": detections}