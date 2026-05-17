# Changelog

All notable user-facing tool changes are tracked here.

## Unreleased

### Added

- PDF Toolkit: added PDF Page Editor operations for extracting selected pages into one PDF, deleting pages, reordering pages, rotating pages, and appending pages from additional PDFs.
- PDF Toolkit: added tests covering generated output PDFs, page counts, page order, rotation, and generated-file metadata for the new page editing operations.
- PDF OCR Text Extractor: added a dedicated local OCR tool for scanned PDFs using Apple Vision plus Tesseract-backed Hebrew support, with English/Hebrew language selection, page-range selection, per-page output, confidence summaries, and metadata for processed pages and recognized lines.
- PDF Toolkit: added metadata inspection for creator, producer, keywords, and date fields plus a Scrub Metadata operation that writes a rebuilt PDF with selected metadata fields blanked.
- Batch Image Resizer & Compressor: added a local multi-image workflow for resizing by width, height, maximum dimension, or scale percentage, output format conversion, quality control, metadata stripping, and collision-safe generated files.
- Image Metadata Inspector: added local EXIF/GPS/color metadata inspection plus a scrub workflow that removes GPS geolocation from generated sharing copies without changing the original image.

### Changed

- README and feature documentation now call out shipped PDF page editing capabilities instead of listing them as future roadmap work.
