# QuickBooks Data Extraction

## Overview

This is a library of scripts used to extract data from QuickBooks Desktop edition.
We have four divisions using QuickBooks: ECH, FP, PCH, SSI.

The goal of this project is extract QBXML data, convert it to CSV files, and then upload to an Azure Data Lake Stroage Gen2 account. From there, Azure resources will ETL it as needed.

## Important Note on files. 

This library has been largely refactored from an old folder. The files found in `bin/` and `bin/queries` are mainly old artifacts from one off scritps all gathered together. These files are kept for guidelines and possible refactoring. The new and approved files are found in `scripts/`. 

The `src/` folder contains other artifacts but may be useful, therefore, and once again, they are being kepted for possible use or refactoring. 