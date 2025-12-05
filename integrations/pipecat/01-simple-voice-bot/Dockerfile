FROM dailyco/pipecat-base:latest

COPY ./python/requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt

COPY ./python/main.py bot.py
COPY ./assets/agent.md assets/agent.md
