# Use the official TensorFlow image as parent
FROM tensorflow/tensorflow:1.14.0-gpu

# Set the working directory
WORKDIR /scratch

# Install some basic utilities
RUN apt-get update --fix-missing && \
    apt-get install -y wget bzip2 ca-certificates curl git

# Install Google Cloud SDK
RUN apt-get update && apt install -y --allow-unauthenticated wget
RUN cd /opt/ && \
	wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-307.0.0-linux-x86_64.tar.gz && \
	tar xvfz google-cloud-sdk-307.0.0-linux-x86_64.tar.gz && \
	./google-cloud-sdk/install.sh
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"

# Install Miniconda with Python 3.7 into /opt
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py37_4.8.2-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh

# Enable Conda and alter bashrc so the Conda default environment is always activated
RUN ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Attach Conda to PATH
ENV PATH /opt/conda/bin:$PATH

# Install a specific version of MEME
RUN wget https://meme-suite.org/meme/meme-software/5.0.1/meme_5.0.1.tar.gz && \
	tar xzf meme_5.0.1.tar.gz && \
	cd meme-5.0.1 && \
    ./configure --prefix=/opt/meme --enable-build-libxml2 --enable-build-libxslt && \
    make && \
    make install
ENV PATH "$PATH:/opt/meme/bin/"
RUN rm -rf meme*

# Install SAMtools, BEDtools, MOODS, and UCSC BedGraphToBigWig
RUN conda install -y -c bioconda samtools bedtools moods ucsc-bedgraphtobigwig 

# Install any remaining needed Python packages specified in requirements.txt
COPY requirements.txt /scratch
RUN pip install -r requirements.txt
RUN rm requirements.txt

# Install jq
RUN apt-get install -y jq


# Clean up after apt and conda
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN conda clean -tipsy

# Set environment variables for Python
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

ARG BPNet_REPO_VER=0.1.2

# Install BPNet repo
RUN pip install git+https://github.com/kundajelab/basepairmodels.git

ARG TFATL_REPO_VER=0.0

# Copy down the TF-Atlas scripts
RUN git clone https://github.com/kundajelab/TF-Atlas.git

# Install BayesianOptimization

RUN pip install bayesian-optimization