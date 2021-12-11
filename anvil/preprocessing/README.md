- check if the github folder path changes in https://github.com/kundajelab/TF-Atlas/blob/main/anvil/preprocessing/run_preprocess.wdl
- why two calls to params.json in create_params.json
- check if create_pipeline_params_json.py has files needed for ATAC/DNASE - default peak ste is overlap peak set? - is controls needed?
- What is the metadata_file?
-  Do I need to change the docker image ? -  docker: 'vivekramalingam/tf-atlas' 
- Do I need to change the Docker file ? - only 2 lines which might be different in Docker - why git clone if this line in docker
- What changed in the create_metadata notebook
- make a check if all are atac or dnase
- Is awk a unix tool already installed?

# Copy down the TF-Atlas scripts
RUN git clone https://github.com/kundajelab/TF-Atlas.git

# cd into the TF-Atlas kubernetes
WORKDIR /tfatlas/TF-Atlas/kubernetes/preprocessing
