import os
import sys

template_path = sys.argv[1]
experiments = sys.argv[2]
encode_version = sys.argv[3]

# read contents of template file as string
with open(template_path, 'r') as f:
    template_str = f.read()

# replace '{}' in the template with experiment name
for experiment in experiments.split():
    yml_str = template_str.replace('{}', experiment.lower())
    yml_str = yml_str.replace('<>', experiment)
    yml_str = yml_str.replace('[]', encode_version)
    
    # write to new yaml file
    yaml_fname = 'job_{}.yml'.format(experiment)
    with open(yaml_fname, 'w') as f:
        f.write(yml_str)
        
    # submit job
    cmd = 'kubectl create -f {}'.format(yaml_fname)
    print(cmd)
    os.system(cmd)
