FROM golang:1.9.0
WORKDIR /app

ADD main /app/
ADD app.conf /app/app.conf
ENTRYPOINT ["/app/main"]
