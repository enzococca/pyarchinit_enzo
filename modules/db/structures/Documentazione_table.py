'''
Created on 15 feb 2018

@author: sere
'''
from modules.db.pyarchinit_conn_strings import Connection
from sqlalchemy import Table, Column, Integer, Date, String, Text, Float, Numeric, MetaData, ForeignKey, engine, create_engine, UniqueConstraint


class Documentazione_table:
    # connection string postgres"
    internal_connection = Connection()

    # create engine and metadata

    engine = create_engine(internal_connection.conn_str(), echo=True, convert_unicode = True)
    metadata = MetaData(engine)

    # define tables
    documentazione_table = Table('documentazione_table', metadata,
    Column('id_documentazione', Integer, primary_key=True),
    Column('sito', Text),
    Column('nome_doc', Text),
    Column('data', Text),
    Column('tipo_documentazione', Text),
    Column('sorgente', Text),
    Column('scala', Text),
    Column('disegnatore', Text),
    Column('note', Text),

    # explicit/composite unique constraint.  'name' is optional.
    UniqueConstraint('sito', 'tipo_documentazione', 'nome_doc', name='ID_invdoc_unico')
    )

    metadata.create_all(engine)