CREATE TABLE media_thumb_table (id_media_thumb INTEGER NOT NULL, id_media INTEGER, mediatype TEXT, media_filename TEXT, media_thumb_filename TEXT, filetype VARCHAR(10), filepath TEXT, path_resize TEXT, PRIMARY KEY (id_media_thumb), CONSTRAINT "ID_media_thumb_unico" UNIQUE (media_thumb_filename) )