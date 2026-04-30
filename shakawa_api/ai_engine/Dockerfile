FROM python:3.9-slim
WORKDIR /app
COPY . .
RUN pip install fastapi uvicorn joblib scikit-learn pandas numpy google-generativeai pthon-dotenv
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8000"]
