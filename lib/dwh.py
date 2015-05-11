# -*- coding: utf-8 -*-
"""
Created on Wed Jan 07 15:36:39 2015

@author: Sean Violante
"""
from sqlalchemy import create_engine

#import psycopg2 as pg

def get_DWH():
	""" Connect to DWH.
	"""
	#conn=pg.connect("host='10.11.0.1' dbname='lendico' user='sviolante' password='3qcqHngX'")
	engine = create_engine('postgresql://sviolante:3qcqHngX@10.11.0.1:5432/lendico')
	return engine
