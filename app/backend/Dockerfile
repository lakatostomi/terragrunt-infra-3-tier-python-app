FROM python:3.12-slim
WORKDIR /app
COPY  . /app/
RUN pip install --upgrade pip
RUN pip install --no-cache-dir --upgrade -r requirements.txt
ENV PORT=8080
EXPOSE $PORT
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port $PORT"]