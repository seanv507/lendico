# -*- coding: utf-8 -*-
"""
Created on Wed Jan 07 15:36:39 2015

@author: Sean Violante
"""
from sqlalchemy import create_engine


def get_DWH():
    """ Connect to DWH.
    """
    engine = create_engine(
        'postgresql://sviolante:3qcqHngX@10.11.0.1:5432/lendico')
    return engine


def read_sql_str(sql_name, dir_name='.', ext=''):
    with open(dir_name + '\\' + sql_name + ext) as sqf:
        sql = sqf.read()
    return sql
