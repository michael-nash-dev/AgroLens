Setup for Python:

1. Install Python (https://wiki.python.org/moin/BeginnersGuide)
2. Install Python packages
   ->pip install -r training/requirements.txt
   ->pip install -r api/requirements.txt'
3. Install TensorFlow Serving (https://www.tensorflow.org/tfx/serving/setup)

----------------------------------------------------------------------------------------------------------------------------------

Setup for ReactJS

1. Install NodeJs (https://nodejs.org/en/download)
2. Install NPM (https://docs.npmjs.com/getting-started)
3. Install dependencies
   
  cd frontend
   ->npm install --from-lock-json
   ->npm audit fix

4. Copy .env.example as .env
5. Change API url in .env
----------------------------------------------------------------------------------------------------------------------------------

Training the Model
1. Download the data from Kaggle (https://www.kaggle.com/datasets/jayaprakashpondy/soil-image-dataset)
2. Only keep the "Train" folder
3. Navigate to soil-image-analysis\training\model-train.ipynb via powershell or command propmpt and run "jupyter notebook"
4. Run all the cells one by one
5. Copy the model generated and save it with the version number in the saved_models folder.
-----------------------------------------------------------------------------------------------------------------------------------

Running the API

Using FastAPI
 1.Get inside api folder
  ->cd api
2. Run the FastAPI Server using uvicorn
  ->uvicorn main:app --reload --host 0.0.0.0
3. Your API is now running at 0.0.0.0:8888 //change to your local port
------------------------------------------------------------------------------------------------------------------------------------

Creating the TF Lite Model

1. Run Jupyter Notebook in Browser.
   ->jupyter notebook
2.  Open training/tf-lite-converter.ipynb in Jupyter Notebook.
3. Run all the cells one by one
4. Model would be saved with a .tflite extension

