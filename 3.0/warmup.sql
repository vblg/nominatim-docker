CREATE EXTENSION pg_prewarm;
SELECT pg_prewarm('placex');
SELECT pg_prewarm('search_name');
SELECT pg_prewarm('place_addressline');
