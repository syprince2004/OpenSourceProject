# 룸췤 AI 모델 학습 과정

본 프로젝트의 객체 탐지 모델은 **YOLOv8**을 사용하여 직접 학습하였습니다.  
로컬 환경에서 데이터를 준비하고 학습을 수행하여, 최종적으로 서비스에 적용 가능한 모델(`best.pt`)을 얻었습니다.  

---

## 학습 환경
- **개발 환경**: Windows 10 + Anaconda + Python 3.9  
- **프레임워크**: PyTorch, Ultralytics YOLOv8  
- **하드웨어**: NVIDIA GPU (CUDA 지원)  

---

## 데이터 준비
- 방 사진을 기반으로 한 **커스텀 데이터셋** 구축  
- Roboflow를 활용해 Bounding Box 라벨링 진행  
- 학습용(`train`), 검증용(`val`), 테스트용(`test`) 데이터로 분리  

---

## 학습 과정
1. YOLOv8 사전 학습 모델(`yolov8m.pt`)을 불러와 전이학습(Fine-tuning) 진행  
2. `data.yaml`을 통해 커스텀 클래스 정의  
3. 아래와 같은 명령어로 학습 수행  

```bash
python train.py --model yolov8m.pt --data data.yaml --epochs 50 --img 640

