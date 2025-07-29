import os
import csv
import json
from decimal import Decimal, getcontext

# 50 significant digits to avoid precision loss on 10**18 scaling 
getcontext().prec = 50

script_dir = os.path.dirname(os.path.abspath(__file__))
input_path = os.path.join(script_dir, "data.csv")
output_path = os.path.join(script_dir, "output.json")

result = []

with open(input_path, newline='') as csvfile:
    reader = csv.reader(csvfile)
    next(reader)

    for row in reader:
        if len(row) < 2 or not row[1].strip():
            raise ValueError(f"Invalid or missing amount in row: {row}")

        address = row[0].strip()

        if not address.startswith("0x") or len(address) != 42:
            raise ValueError(f"Invalid Ethereum address: '{address}'")

        amount_str = row[1].replace(",", "").strip()
        amount = Decimal(amount_str) * Decimal(10**18)
        result.append({
            "addr": address,
            "amount": int(amount)
        })

result.sort(key=lambda x: x["amount"])
print(json.dumps(result, indent=2))

# Save to output.json
with open(output_path, "w") as outfile:
    json.dump(result, outfile, indent=2)
