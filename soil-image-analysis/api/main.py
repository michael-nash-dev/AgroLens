import numpy as np
from fastapi import FastAPI, File, UploadFile
import uvicorn
from io import BytesIO
from PIL import Image
import tensorflow as tf
from starlette.middleware.cors import CORSMiddleware

app = FastAPI()

origins = [
    "http://localhost",
    "http://localhost:3000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET","POST"],
    allow_headers=["*"],

)

MODEL = tf.keras.models.load_model("../saved_models/1.keras")
CLASS_NAMES = ["Alluvial Soil", "Black Soil", "Clay Soil", "Red Soil"]

@app.get("/ping")
async def ping():
    return "Hello, i'm alive"

def read_file_as_image(data) -> np.ndarray:
   image = np.array(Image.open(BytesIO(data)))

   return image

@app.post("/predict")
async def predict(
        file: UploadFile = File(...)
):
    image = read_file_as_image(await file.read())

    img_batch = np.expand_dims(image,0)

    predictions = MODEL.predict(img_batch)

    predicted_class = CLASS_NAMES[np.argmax(predictions[0])]
    confidence= np.max(predictions[0])

    return{
        'class': predicted_class,
        'confidence': float(confidence)

    }



if __name__ == "__main__":
    uvicorn.run(app,host="localhost", port=8888)