# City correlation mapping

Fetches and parses mediawiki markup, computes cosine similarities of pages, and produces dense arrow buffers of every page with a coordinate and the top 20 similar pages to it.

Uses Docker images from `lsb/mediawiki-json-revisions` and `lsb/mediawiki-json-coords`, and produces arrow files that are used by `lsb/sister-cities-map`.
