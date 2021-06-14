# Adding a new watermark

1) Find or create a vector graphics version of the watermark, and place it inside the `svg/` folder.
2) Create a new entry in `marks.json`. Set `file` and `name` appropriately. Run `magick identify -format "%[fx:w]x%[fx:h]" my-new-watermark.svg` to get SVG dimensions, and put them in the `width` and `height`, respectively.
3) Open `comp.psd`, add the watermark as a new layer, and place it where it looks best relative to the existing watermarks. When done, save the PSD.
4) Save the current logo height in the `normalized_height` field in the new `marks.json` entry.
5) Find a reference point in the watermark that is easily measurable in both the vector graphics file as well as the bitmap. Measure the offset of that reference point from the top left corner of the PSD, and save them in the `offset` of the appropriate corner in the `marks.json` entry.
6) Find the coordinates of that same reference point in the vector image, and save them in the `anchor` of the appropriate corner.

Done!