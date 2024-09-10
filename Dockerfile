FROM python:slim-bullseye


LABEL maintainer="AquilaX Ltd <admin[AT]aquilax.ai>"

RUN apt update -y
RUN apt install -y curl

ENV PYTHONUNBUFFERED=1

COPY ./ /app

WORKDIR /app/

ENV PYTHONPATH=/app
