# BatchAudit:  Batch Transfer Checker

This repository contains a Python script, `batchTransfer_check.py` and 'tx_analysis.py', which analyzes a directory of ERC-1155 contracts and outputs a JSON report of safeBatchTransfer-related security checks. erc_ground_truth_test/erc_annotated_ground_truth.json file describes the test strategy anf tool measurements. 
## Prerequisites

- **Python 3.8+**  
- Git (to clone the repository)  
- (Optional) A virtual environment tool, such as `venv` or `conda`

## Installation 

1. **Clone the repository**

   ```bash
   git clone https://github.com/BatchTransfer/BATCHAUDIT.git
   cd BATCHAUDIT


pip install -r requirements.txt

pip install eth_utils web3

## Usage:

**Set up your input and output paths**
In batchTransfer_check.py, ensure the following variables point to the correct local paths:

  
  erc1155_directory = "LOCAL/PATH/BATCHAUDIT-Anon/BATCHAUDIT/ERC1155-ethereum/ERC1155"
  erc1155_output_file = "/LOCAL/PATH/BATCHAUDIT-Anon/BATCHAUDIT/erc1155_SafeBatch_ALL_ONE.json"
  
  Replace LOCAL/PATH/BATCHAUDIT-Anon/BATCHAUDIT/ERC1155-ethereum/ERC1155 with the actual filesystem path where your ERC-1155 contract files are stored.
  Replace /LOCAL/PATH/BATCHAUDIT-Anon/BATCHAUDIT/erc1155_SafeBatch_ALL_ONE.json with the desired output file path.


## Run the batch transfer checker


1. **Run the repository**

   ```bash
   python3 batchTransfer_check.py


batchTransfer_check.py: Python script that scans ERC-1155 contracts for safeBatchTransfer vulnerabilities.
ERC1155-ethereum/ERC1155/: Example folder where you place the Solidity or JSON‐ABI files for ERC-1155 contracts.
erc1155_SafeBatch_ALL_ONE.json: Sample output file (location defined by erc1155_output_file).



## Directory Structure

BATCHAUDIT/
├── batchTransfer_check.py       # Main analysis script
├── ERC1155-ethereum/
│   └── ERC1155/                 # Directory containing ERC-1155 contract files
├── erc1155_SafeBatch_ALL_ONE.json  # Example output path (created at runtime)
├── requirements.txt             # (Optional) Python dependencies
└── README.md                    # This file



## Troubleshooting

“ModuleNotFoundError”
Make sure you installed all dependencies via pip install -r requirements.txt. If a specific import fails, install it manually:
