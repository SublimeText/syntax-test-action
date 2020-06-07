FROM buster-slim:latest

RUN RUN apt-get update && apt-get install -y \
  git \
  libgl1-mesa-glx \
  libglu1-mesa \
  wget

ENTRYPOINT ['/entrypoint.sh']
