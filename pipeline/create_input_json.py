# python script to create an input json for the training step
#
# For e.g.
# {
#     "task0_plus": {"strand": 0,
#                    "task_id": 0,
#                    "signal": "bigWigs/ENCSR000BGZ_plus.bw",
#                    "control": "bigWigs/ENCSR000BGZ_control_plus.bw",
#                    "peaks": "downloads/ENCFF068YYR.bed.gz"},
#     "task0_minus": {"strand": 1,
#                     "task_id": 0,
#                     "signal": "bigWigs/ENCSR000BGZ_minus.bw",
#                     "control": "bigWigs/ENCSR000BGZ_control_minus.bw",
#                     "peaks": "downloads/ENCFF068YYR.bed.gz"}
# }

import sys
import json

# command line params
experiments = sys.argv[1].split(' ')
peaks = sys.argv[2].split(' ')
stranded = bool(sys.argv[3])
has_control = bool(sys.argv[4])
bigWigs_dir = sys.argv[5]
peaks_dir = sys.argv[6]
output_dir = sys.argv[7]

if len(experiments) != len(peaks):
    print("# of experiments should match # of peaks. Aborting pipeline")
    sys.exit(1)

# we'll create a dictionary first and write it out as json
input_dict = {}

# we can create a multitask input json if more than one experiment
# is specified
for i in range(len(experiments)):
    experiment = experiments[i]
    if stranded:
        # create one model task for each strand
        strands =['plus', 'minus']
        for j in range(len(strands)):
            strand = strands[j]
            task_id = "task{}_{}".format(i, strand)
            task_dict = {}
            task_dict["strand"] = j
            # this is the experiment task id, will be same for 
            # plus and minus strand pair
            task_dict["task_id"] = i
            task_dict["signal"] = '{}/{}_{}.bigWig'.format(
                bigWigs_dir, experiment, strand)
            task_dict["peaks"] = '{}/{}.bed.gz'.format(peaks_dir, peaks[i])

            if has_control:
                task_dict["control"] = '{}/{}_control_{}.bigWig'.format(
                    bigWigs_dir, experiment, strand)

            input_dict[task_id] = task_dict
    else:
        # one model task for each experiment
        task_id = "task{}".format(i)
        task_dict = {}
        task_dict["strand"] = 0
        task_dict["task_id"] = i
        task_dict["signal"] = '{}/{}.bigWig'.format(bigWigs_dir, experiment)
        task_dict["peaks"] = '{}/{}.bed.gz'.format(peaks_dir, peaks[i])

        if has_control:
            task_dict["control"] = '{}/{}_control.bw'.format(
                bigWigs_dir, experiment)
        
        input_dict[task_id] = task_dict

output_basename = '_'.join(experiments)
output_filenane = '{}/{}.json'.format(output_dir, output_basename)

# write dictionary to json
with open(output_filenane, 'w') as outf:
    json.dump(input_dict, outf, indent=4)
