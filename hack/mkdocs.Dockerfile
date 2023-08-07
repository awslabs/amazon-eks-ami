FROM python:3.9
RUN pip install mkdocs mkdocs-material
WORKDIR /workdir
ENTRYPOINT ["mkdocs"]