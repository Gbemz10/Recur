# Product documents

`prd-mono.md` is the product requirements document written for Mono's
compliance review: what Recur does, where Mono sits in the flow, which fields
are requested and what each one is for, and how the data is handled.

The screenshots in `screens/` are downscaled copies of real app captures, sized
for print rather than for display.

To regenerate the PDF, convert the markdown and print it with headless Chrome.
There is no pandoc on the build machine; the converter used lives in the
session scratchpad and can be rewritten in a few lines if needed.

The compliance counterpart to this document is `docs/data-protection/`.
