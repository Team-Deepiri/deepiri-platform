# Manual Testing Guide: Document Processing Dependencies

## Overview

This guide helps you manually test the PDF plumber and document processing dependencies that were just fixed in the Cyrex interface.

## Prerequisites

- Docker installed and running
- Node.js installed (for frontend)
- Python 3.10+ installed (for backend)
- Access to the Deepiri platform

## Testing Options

### Option 1: Test the Agent Playground Document Upload (Recommended)

#### Step 1: Start the Cyrex Interface

**Method A: Using Docker Compose (Easiest)**

```bash
# Navigate to the project root
cd deepiri-platform

# Start the Cyrex interface only
docker compose -f docker-compose.dev.yml up -d cyrex-interface

# Or start all services
docker compose -f docker-compose.dev.yml up -d
```

**Method B: Using Skaffold (Production-like)**

```bash
# Start Minikube (if not already running)
minikube start --driver=docker --cpus=4 --memory=8192
eval $(minikube docker-env)

# Start with Skaffold
skaffold dev --port-forward
```

**Method C: Local Development**

```bash
# Navigate to Cyrex interface
cd deepiri-platform/diri-cyrex/cyrex-interface

# Install dependencies (if not already done)
npm install

# Start the frontend
npm run dev
```

#### Step 2: Access the Agent Playground

Once the services are running, access the interface:

- **Frontend URL:** http://localhost:5173 (if using local dev)
- **Or check the Docker logs for the exact URL**

#### Step 3: Test Document Upload

1. **Navigate to Agent Playground**

   - Look for "Agent Playground" or "Document Processing" in the interface
   - This should be accessible through the main navigation

2. **Upload Test Documents**
   Try uploading these document types:

   - **PDF files** (text-based and scanned)
   - **DOCX files** (Word documents)
   - **Image files** (PNG, JPG - for OCR testing)
   - **HTML files**
   - **Excel files** (XLSX)

3. **Verify Processing**
   - Check if documents upload successfully
   - Verify text extraction works
   - Look for any error messages
   - Test different file sizes (small and large documents)

#### Step 4: Test Specific Features

**PDF Processing:**

- Upload a PDF with text content
- Verify text is extracted correctly
- Check if tables are detected

**OCR Testing:**

- Upload a scanned PDF or image
- Verify OCR processes the image
- Check extracted text quality

**Document Type Detection:**

- Upload different file types
- Verify the system correctly identifies document types

### Option 2: Test Document Processing Services Directly

#### Step 1: Start the Python Backend

```bash
# Navigate to Cyrex backend
cd deepiri-platform/diri-cyrex

# Activate virtual environment (if exists)
source venv/bin/activate  # Linux/Mac
# or venv\Scripts\activate  # Windows

# Install dependencies (if not already done)
pip install -r requirements.txt

# Start the backend
uvicorn app.main:app --reload --port 8000
```

#### Step 2: Test API Endpoints

Use a tool like **Postman** or **curl** to test the document processing API:

```bash
# Test document parsing endpoint
curl -X POST "http://localhost:8000/api/agent/spreadsheet/parse-document" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/path/to/your/test.pdf" \
  -F "use_ocr=true" \
  -F "extract_tables=true"
```

#### Step 3: Test Individual Dependencies

Create a simple Python script to test each dependency:

```python
# test_document_processing.py
import sys

print("Testing document processing dependencies...")

# Test pdfplumber
try:
    import pdfplumber
    print(f"✓ pdfplumber {pdfplumber.__version__}")
except ImportError as e:
    print(f"✗ pdfplumber: {e}")

# Test python-docx
try:
    import docx
    print("✓ python-docx available")
except ImportError as e:
    print(f"✗ python-docx: {e}")

# Test PyPDF2
try:
    import PyPDF2
    print(f"✓ PyPDF2 {PyPDF2.__version__}")
except ImportError as e:
    print(f"✗ PyPDF2: {e}")

# Test Pillow
try:
    from PIL import Image
    print("✓ Pillow available")
except ImportError as e:
    print(f"✗ Pillow: {e}")

# Test pdf2image
try:
    import pdf2image
    print("✓ pdf2image available")
except ImportError as e:
    print(f"✗ pdf2image: {e}")

# Test beautifulsoup4
try:
    from bs4 import BeautifulSoup
    print("✓ beautifulsoup4 available")
except ImportError as e:
    print(f"✗ beautifulsoup4: {e}")

# Test openpyxl
try:
    import openpyxl
    print("✓ openpyxl available")
except ImportError as e:
    print(f"✗ openpyxl: {e}")

# Test tabula-py
try:
    import tabula
    print("✓ tabula-py available")
except ImportError as e:
    print(f"✗ tabula-py: {e}")

# Test camelot-py
try:
    import camelot
    print("✓ camelot-py available")
except ImportError as e:
    print(f"✗ camelot-py: {e}")

# Test chardet
try:
    import chardet
    print(f"✓ chardet {chardet.__version__}")
except ImportError as e:
    print(f"✗ chardet: {e}")

# Test unidecode
try:
    import unidecode
    print("✓ unidecode available")
except ImportError as e:
    print(f"✗ unidecode: {e}")

print("All tests completed!")
```

Run the test script:

```bash
cd deepiri-platform/diri-cyrex
python test_document_processing.py
```

### Option 3: Test with Real Documents

#### Step 1: Prepare Test Documents

Create or find these document types:

- **Invoice PDF** (text-based)
- **Scanned PDF** (image-based)
- **Word document** (.docx)
- **Excel spreadsheet** (.xlsx)
- **HTML file**
- **Plain text file** (.txt)

#### Step 2: Test Each Document Type

1. **Upload each document type** to the Agent Playground
2. **Verify successful processing**
3. **Check extracted content quality**
4. **Note any errors or issues**

#### Step 3: Test Edge Cases

- **Large documents** (>10MB)
- **Password-protected PDFs**
- **Corrupted files**
- **Unsupported file types**

### Option 4: Integration Testing

#### Step 1: End-to-End Test

1. **Start all services**
2. **Upload a document** through the interface
3. **Verify the entire pipeline works:**
   - Upload → Processing → Storage → Display

#### Step 2: Performance Testing

Test with multiple documents simultaneously:

- Upload 5-10 documents at once
- Verify system handles concurrent processing
- Check for memory leaks or performance issues

## Expected Results

### ✅ Success Indicators

1. **No import errors** when starting services
2. **Successful document uploads** without crashes
3. **Text extraction works** for PDFs and DOCX files
4. **OCR processes images** and scanned PDFs
5. **Document type detection** correctly identifies file formats
6. **No dependency conflicts** or version issues

### ❌ Failure Indicators

1. **Import errors** for pdfplumber or other dependencies
2. **Document upload failures** with error messages
3. **Empty text extraction** from documents
4. **OCR failures** for image-based documents
5. **Service crashes** during document processing

## Troubleshooting

### Common Issues

**"ModuleNotFoundError: No module named 'pdfplumber'"**

- Reinstall dependencies: `pip install pdfplumber`
- Check virtual environment activation

**"TesseractNotFoundError"**

- Install Tesseract OCR: `brew install tesseract` (macOS)
- Or set TESSERACT_PATH environment variable

**"Document upload fails"**

- Check file size limits
- Verify file format support
- Check service logs for errors

**"Poor OCR quality"**

- Ensure Tesseract is installed
- Try different OCR languages
- Check image quality

### Getting Help

1. **Check service logs:**

   ```bash
   docker compose -f docker-compose.dev.yml logs cyrex
   ```

2. **Verify dependencies:**

   ```bash
   pip list | grep -E "(pdfplumber|pytesseract|Pillow)"
   ```

3. **Test individual components:**
   - Run the Python test script above
   - Test API endpoints with curl/Postman

## Test Report Template

After testing, document your results:

```markdown
## Test Results

**Date:** [DATE]
**Tester:** [YOUR NAME]
**Environment:** [Local/Docker/Skaffold]

### Document Upload Tests

- [ ] PDF upload: ✅/❌
- [ ] DOCX upload: ✅/❌
- [ ] Image upload: ✅/❌
- [ ] HTML upload: ✅/❌
- [ ] Excel upload: ✅/❌

### Processing Tests

- [ ] PDF text extraction: ✅/❌
- [ ] OCR processing: ✅/❌
- [ ] Document type detection: ✅/❌
- [ ] Table extraction: ✅/❌

### Issues Found

1. [Issue description]
2. [Issue description]

### Notes

[Any additional observations or notes]
```

## Next Steps

If all tests pass:

- ✅ Document processing dependencies are working correctly
- ✅ Agent Playground document upload should work
- ✅ Ready for production use

If tests fail:

- 🔄 Check the troubleshooting section
- 🔄 Reinstall dependencies if needed
- 🔄 Contact the development team with error details

---

**Last Updated:** February 2026
**Maintained by:** Development Team
