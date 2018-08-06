# -*- coding: utf-8 -*-
"""
/***************************************************************************
    pyArchInit Plugin  - A QGIS plugin to manage archaeological dataset
    stored in Postgres
    -------------------
    begin                : 2018-08-06
    copyright            : (C) 2018 by Salvatore Larosa
    email                : lrssvtml (at) gmail (dot) com
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *																		*
 ***************************************************************************/
"""

import io
from sqlalchemy import create_engine, MetaData
from sqlalchemy.orm import sessionmaker
from sqlalchemy_utils import database_exists, create_database


class SchemaDump(object):
    def __init__(self, db_url, schema_file_path):
        self.db_url = db_url
        self.schema_file_path = schema_file_path
        self.buf = io.BytesIO()

    def dump_shema(self):
        engine = create_engine(self.db_url)
        metadata = MetaData()
        metadata.reflect(engine)

        def dump(sql, *multiparams, **params):
            f = sql.compile(dialect=engine.dialect)
            self.buf.write(str(f))
            self.buf.write(str(';\n'))

        new_engine = create_engine(self.db_url, strategy='mock', executor=dump)
        metadata.create_all(new_engine, checkfirst=True)

        with io.open(self.schema_file_path, 'wb+') as schema:
            schema.write(self.buf.getvalue())


class RestoreSchema(object):
    def __init__(self, db_url, schema_file_path):
        self.db_url = db_url
        self.schema_file_path = schema_file_path

    def restore_schema(self):
        raw_schema = ''
        with io.open(self.schema_file_path) as sql_schema:
            raw_schema = sql_schema.read()
        engine = create_engine(self.db_url)
        Session = sessionmaker(bind=engine)
        session = Session()
        conn = engine.connect()
        transaction = conn.begin()
        try:
            conn.execute(raw_schema)
            transaction.commit()
        except Exception as e:
            transaction.rollback()
            raise e
        finally:
            session.close()


class CreateDatabase(object):

    def __init__(self, db_name, db_host):
        self.db_name = db_name
        self.db_host = db_host

    def creatdb(self):
        engine = create_engine("postgres://{}/{}".format(self.db_host, self.db_name))
        if not database_exists(engine.url):
            create_database(engine.url)

        print(database_exists(engine.url))