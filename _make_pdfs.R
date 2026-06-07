# Convert the writeups to PDF (keeps the embedded figures).
# One-time setup:  install.packages(c("rmarkdown", "pagedown"))
# pagedown::chrome_print uses your installed Chrome to render the PDF — no LaTeX required.

library(rmarkdown)

files <- c("Analysis 1 - Writeup.md", "Analysis 2 - Writeup.md")

for (f in files) {
  html <- render(f, output_format = "html_document", quiet = TRUE)  # md -> html (images embed)
  out  <- sub("\\.md$", ".pdf", f)
  pagedown::chrome_print(html, output = out)                        # html -> pdf via Chrome
  message("Wrote ", out)
}
