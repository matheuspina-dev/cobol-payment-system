import random
import os

NUM_ACCOUNTS = 1000
NUM_TRANSACTIONS = 1500


def generate_accounts():
    print(f"Generating {NUM_ACCOUNTS} accounts...")
    with open("data/ACCOUNTS.TXT", "w") as f:
        for i in range(1, NUM_ACCOUNTS + 1):
            acc_id = f"{i:06d}"
            balance = random.randint(100, 50000)
            f.write(f"{acc_id},{balance}\n")


def generate_transactions():
    print(f"Generating {NUM_TRANSACTIONS} transactions...")
    tx_types = ["DEBIT", "CREDIT"]

    with open("data/TRANSACTIONS.TXT", "w") as f:
        for _ in range(NUM_TRANSACTIONS):
            acc_num = random.randint(1, NUM_ACCOUNTS + 50)
            acc_id = f"{acc_num:06d}"
            t_type = random.choices(tx_types, weights=[0.8, 0.2])[0]
            amount = random.randint(10, 600)
            f.write(f"{acc_id},{t_type},{amount}\n")


if __name__ == "__main__":
    os.makedirs("data", exist_ok=True)
    os.makedirs("output", exist_ok=True)

    generate_accounts()
    generate_transactions()
    print("Test data generated successfully in the 'data/' directory!")
