#!/usr/bin/env python3
__author__ = 'Decker'

import sys
import json
if len(sys.argv) != 2:
    print("You should specify the notaries.json file produced by prepare-notaries.sh")
    exit(1)

default_port = 17777

elected = {} # dict
elected["port"] = default_port

input_file = open (str(sys.argv[1]))
json_array = json.load(input_file)
print("%s parsed, found %d notaries ... " % (sys.argv[1], len(json_array)))

minsigs = len(json_array)
elected["BTCminsigs"] = minsigs
elected["minsigs"] = minsigs
seeds = [] # list
notaries = []

for i in range(minsigs):
    seeds.append('172.17.0.{0}'.format(2 + i))
elected["seeds"] = seeds

notary_id = 0
for item in json_array: # json_array - list
    if 'pubkey' in item.keys():
        notaries.append({'node_docker_{0}'.format(notary_id) : item['pubkey']})
        notary_id = notary_id + 1
elected["notaries"] = notaries
elected.update({"author" : __author__})

# with open("docker_test_elected", "w+") as f:
#     json.dump(elected, f, indent=2)

elected_file_name = "docker_test_elected"
try:
    f = open(elected_file_name, "w")
except IOError:
    print("Error happened during writing {0} ...".format(elected_file_name))
    exit(1)
else:
    with f:
        json.dump(elected, f, indent=2)
print('{0} successfully written'.format(elected_file_name))

with open('import_privkeys', 'w') as f:
    for item in json_array:
        if 'wif' in item.keys():
            f.write('./komodo-cli importprivkey %s "" false\n' % (item['wif']))

# https://realpython.com/python-formatted-output/
# https://pythonworld.ru/osnovy/formatirovanie-strok-metod-format.html
# https://docs.python.org/3/library/json.html
