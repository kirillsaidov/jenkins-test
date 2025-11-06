FROM python:3.12

# set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PORT=8080

# update timezone to display correct time
RUN ln -sf /usr/share/zoneinfo/Asia/Almaty /etc/localtime
RUN echo "Asia/Almaty" | tee /etc/timezone

# set working directory
WORKDIR /app

# copy project files to the working directory
COPY . .

# command to run the application
ENTRYPOINT ["python", "-m", "http.server"]
