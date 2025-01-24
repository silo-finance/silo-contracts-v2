import csv
import json
import os
import argparse

# Inicjalizacja parsera argumentów
parser = argparse.ArgumentParser(description="Obsługa nazwanych parametrów w Pythonie.")
parser.add_argument("--chain", type=str, required=True, help="Nazwa dla parametru 'chain'.")

# Parsowanie argumentów
args = parser.parse_args()

# Pobranie wartości parametru
chain = args.chain

# Wyświetlenie odczytanej wartości
print(f"Parametr --chain ustawiony na: {chain}")

# Relatywne ścieżki
script_dir = os.path.dirname(os.path.abspath(__file__))  # Lokalizacja skryptu
input_file = os.path.join(script_dir, chain, "raw/data.csv")  # Relatywna ścieżka do pliku CSV
output_file = os.path.join(script_dir, chain, "raw/market.json")  # Relatywna ścieżka do pliku JSON

# Klucze JSON
keys = [
 "LP",
 "Blockchain",
 "market",
 "token",
 "address",
 "-",
 "Borrowable",
 "maxLtv",
 "lt",
 "liquidationTargetLtv",
 "liquidationFee",
 "interestRateModelConfig",
 "ORacle Provider",
 "ORacle Address",
 "daoFee",
 "DAO's fee recpient",
 "Deployer fee",
 "Deployer's fee recpient",
 "_1",
 "_2",
]

# Sprawdzenie, czy plik wejściowy istnieje
if not os.path.isfile(input_file):
    print(f"Plik {input_file} nie istnieje!")
    exit(1)

# Wczytanie CSV i zapis do JSON
with open(input_file, "r", newline="\n", encoding="utf-8") as csvfile:
    reader = csv.reader(csvfile, delimiter=",")
    data = []

    for row in reader:
        if len(row) != len(keys):
            print("Liczba kolumn w pliku CSV nie zgadza się z liczbą kluczy.")
            print("cols:", len(row), "keys:", len(keys))
            print(row)
            exit(1)
        data.append({keys[i]: row[i] for i in range(len(keys))})

print("sample:", data[1]["_1"])

with open(output_file, "w", encoding="utf-8") as jsonfile:
    json.dump(data, jsonfile, indent=4, ensure_ascii=False)

print(f"Dane zostały zapisane w pliku {output_file}")
