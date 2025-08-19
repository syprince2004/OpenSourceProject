from ultralytics import YOLO

model = YOLO("/Users/eunhong/Projects/OpenSWProject/yolo-model/best.pt")

# 클래스 목록 출력
print(model.names)
