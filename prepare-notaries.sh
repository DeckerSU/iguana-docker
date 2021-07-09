#!/usr/bin/env bash

# Copyright (c) 2021 Decker
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Requirements:
# sudo apt install base58 or install it manually from https://github.com/keis/base58
# sudo apt install jq

# Output:

# notaries.json at <stdout> in a form of:
# [
#   {
#     "id": "1",
#     "passphrase": "fa2511419ea73899a2be34dbd3f172bd173d4d045d1163d4e370305564ea73ce",
#     "address": "RHSKEzvQD9o3xScf7g64WEpRfGox6zpMYM",
#     "wif": "UsFnnktnXcvxwGaGsvWfHhD7Ej444YVibyYCJqrRp2jDzWLA2fTo",
#     "pubkey": "02bb7ab714d858f5da75f93fdb0ab93822f142054262a4425205bb70efe7225394"
#   },
# ...
# ]

nn_count=3
json="[]"

# https://stackoverflow.com/questions/169511/how-do-i-iterate-over-a-range-of-numbers-defined-by-variables-in-bash
for i in $(seq 1 ${nn_count}); do 
    echo "--> Deploying credentials for NN#${i}" 1>&2
    passphrase=$(openssl rand 32 | xxd -p -c 32)
    #passphrase="myverysecretandstrongpassphrase_noneabletobrute"
    
    echo "Passphrase: $passphrase" 1>&2
    # better to don't store any binary values in variables, that's why we convert it
    # to hex first and further operating with hex only
    sha256_hex=$(echo -n "${passphrase}" | openssl dgst -sha256 -binary | xxd -p -c 32)
    
    if [ "${#sha256_hex}" -ne "64" ]; then
        echo "Error generating sha256 ..." 1>&2
        exit
    fi

    # myverysecretandstrongpassphrase_noneabletobrute - 907ece717a8f94e07de7bf6f8b3e9f91abb8858ebf831072cdbb9016ef53bc9d
    # https://unix.stackexchange.com/questions/9468/how-to-get-the-char-at-a-given-position-of-a-string-in-shell-script

    # echo ${sha256_hex}
    h0=$((16#${sha256_hex:0:2}))
    h0=$((${h0} & 248))
    h0=$(printf '%02x' ${h0})
    h31=$((16#${sha256_hex:62:2}))
    h31=$(((${h31} & 127) | 64))
    h31=$(printf '%02x' ${h31})

    privkey_hex=$(echo -n "${h0}${sha256_hex:2:60}${h31}")
    
    if [ "${#privkey_hex}" -ne "64" ]; then
        echo "Error generating privkey ..." 1>&2
        exit
    fi

    echo "Privkey (hex): $privkey_hex (${#privkey_hex})" 1>&2

    pre_string="30740201010420"
    pre_string_other="302e0201010420"
    mid_string="a00706052b8104000aa144034200" # identifies secp256k1
    secp256k1_oid_string="06052b8104000a"
    # 06 05 2B 81 04 00 0A, https://thalesdocs.com/gphsm/luna/7/docs/network/Content/sdk/using/ecc_curve_cross-reference.htm

    pubkey_hex=$(openssl ec -inform DER -in <(echo "${pre_string_other} ${privkey_hex} ${mid_string:0:18}" | xxd -r -p) -pubout -conv_form compressed -outform DER 2>/dev/null | xxd -p -c 56)
    pubkey_hex=$(echo $pubkey_hex | sed 's/3036301006072a8648ce3d020106052b8104000a032200//')
    if [ "${#pubkey_hex}" -ne "66" ]; then
        echo "Error obtaining pubkey ..." 1>&2
        exit
    fi
    echo " Pubkey (hex): ${pubkey_hex} (${#pubkey_hex})" 1>&2

    network_byte_hex="3c" #  60 (dec) KMD (Komodo)
    secret_key_hex="bc"   # 188 (dec) KMD (Komodo)

    hash160_hex=$(echo -n "${pubkey_hex}" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -rmd160 -binary | xxd -p -c 20)
    if [ "${#hash160_hex}" -ne "40" ]; then
        echo "Error obtaining rmd-160 ..." 1>&2
        exit
    fi
    echo "rmd-160 (hex): $hash160_hex (${#hash160_hex})" 1>&2
    checksum_hex=$(echo -n "${network_byte_hex}${hash160_hex}" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | xxd -p -c 32)
    address=$(echo -n "${network_byte_hex}${hash160_hex}${checksum_hex:0:8}" | xxd -r -p | base58)
    echo "      Address: ${address}" 1>&2

    wif_checksum_hex=$(echo -n "${secret_key_hex}${privkey_hex}01" | xxd -r -p | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | xxd -p -c 32)
    wif=$(echo -n "${secret_key_hex}${privkey_hex}01${wif_checksum_hex:0:8}" | xxd -r -p | base58)
    echo "          WIF: ${wif}" 1>&2

    json_elem=$(jq  --arg key0 'id' \
        --arg value0 "${i}" \
        --arg key1 'passphrase' \
        --arg value1 "${passphrase}" \
        --arg key2 'address' \
        --arg value2 "${address}" \
        --arg key3 'wif' \
        --arg value3 "${wif}" \
        --arg key4 'pubkey' \
        --arg value4 "${pubkey_hex}" \
        '. | .[$key0]=$value0 | .[$key1]=$value1 | .[$key2]=$value2 | .[$key3]=$value3 | .[$key4]=$value4' <<< "{}");
    
    # https://stackoverflow.com/questions/42245288/add-new-element-to-existing-json-array-with-jq

    json=$(jq ". + [${json_elem}]" <<< ${json});

done

echo "${json}" | jq .;


