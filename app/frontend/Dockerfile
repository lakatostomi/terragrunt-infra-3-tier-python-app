FROM python:3.12-slim
WORKDIR /app
COPY  /frontend/ /app/
RUN pip install --upgrade pip
RUN pip install --no-cache-dir --upgrade -r requirements.txt
ENV PORT=8080
EXPOSE $PORT
ENTRYPOINT ["sh", "-c", "streamlit run main.py --server.port=$PORT --server.address=0.0.0.0"]