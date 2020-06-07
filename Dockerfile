FROM ubuntu

RUN apt-get update && apt-get install -y \
  libcairo2 \
  libgl1-mesa-glx \
  libglib2.0-0 \
  libglu1-mesa \
  libgtk-3-0 \
  libpango-1.0-0 \
  libpangocairo-1.0-0 \
  wget

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
