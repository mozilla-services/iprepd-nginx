FROM python:3.7.2-alpine

RUN pip install --upgrade pip

RUN adduser -D tester
USER tester
WORKDIR /home/tester

ENV PATH="/home/tester/.local/bin:${PATH}"
RUN pip install --user pipenv

COPY --chown=tester:tester requirements.txt requirements.txt
RUN pip install --user -r requirements.txt

COPY e2e_test.py e2e_test.py
ENV LOG_LEVEL="INFO"

ENTRYPOINT pytest -s --log-cli-level=${LOG_LEVEL}
