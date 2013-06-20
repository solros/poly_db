#!/usr/bin/python

#from elementtree import ElementTree
import xml.etree.cElementTree as ElementTree
import sys
import array
import string
import pymongo
import datetime
import time

simple_properties = [
	'CONE_DIM', 
	'N_VERTICES', 
	'N_FACETS'
	'FACET_WIDTH',
	'LATTICE_VOLUME',
	'N_INTERIOR_LATTICE_POINTS',
	'N_BOUNDARY_LATTICE_POINTS',
	'CANONICAL',
	'COMPRESSED',
	'ESSENTIALLY_GENERIC',
	'GORENSTEIN',
	'LATTICE_CODEGREE',
	'LATTICE_DEGREE',
	'REFLEXIVE',
	'SMOOTH',
	'TERMINAL',
	'VERY_AMPLE'
]

vector_properties = [
	'FACET_WIDTHS',
	'H_STAR_VECTOR',
	'EHRHART_POLYNOMIAL_COEFF'
]

matrix_properties = [
	'VERTICES',
	'FACETS'
]

def poly2dict(file, contrib, date): 
	start()		
	tree = ElementTree.parse(file)
	root = tree.getroot()

	mt('parse')
	
	name = root.attrib['name']
# 	type = root.attrib['type']
	
	start()
	dict = {}
	
	dict['_id'] = name
	dict['date'] = date
	dict['contributor'] = contrib
# 	dict['type'] = type

	for p in root.iter('{http://www.math.tu-berlin.de/polymake/#3}property'):
		key = p.attrib['name']
		if key in simple_properties:
			val = p.attrib['value']
			if val == 'false': 
				val = 0
			elif val == 'true':
				val = 1
			else:
				val = int(val)
			dict[key] = val
	mt('dict')
	return dict


def poly2json(dict):
	return make_json_string(dict)

def make_json_simple(key, value):
	return ''.join(['"',key,'": "',value,'"'])

def make_json_string(dict):
	s = "{\n" +	string.join((make_json_simple(k,v) for k,v in dict.iteritems()), ',\n') + "\n}"
	return s
	
	

def add_to_db(obj, contrib):
	mongo = pymongo.MongoClient("localhost", 27017)
	db = mongo.pm
	db.test.insert(poly2dict(obj, contrib, datetime.datetime.now().strftime("%Y-%m-%d")))


def add_list_to_db(objects, contrib):
	mongo = pymongo.MongoClient("localhost", 27017)
	db = mongo.pm
	date = datetime.datetime.now().strftime("%Y-%m-%d")
	docs = []
	for obj in objects:
		docs.append(poly2dict(obj, contrib, date))
	start()
	db.test2.insert(docs)
	mt('db')

def pt(s):
	print s
	print time.time()-starting_time


def start():
	global clock
	clock = time.time()
	

def mt(x):
	global parsetime
	global dicttime
	global dbtime
	dur = time.time()-clock
	if x == 'parse':
		parsetime += dur
	if x == 'dict':
		dicttime += dur
	if x == 'db':
		dbtime += dur

def printtime():
	print "parsing: " + repr(parsetime)
	print "dictionary: " + repr(dicttime)
	print "db: " + repr(dbtime)

		
clock = 0	
parsetime = 0
dicttime = 0
dbtime = 0
starting_time = time.time()

contrib = "Andreas Paffenholz"
date = datetime.datetime.now().strftime("%Y-%m-%d")
add_list_to_db(sys.argv[1:] , contrib)
printtime()
#print poly2dict(sys.argv[1],contrib,date)