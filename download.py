import os, re
import logging
from datetime import datetime, timedelta
from itertools import product, count
from multiprocessing import Pool
from requests import get, head
from urllib2 import urlopen, HTTPError

"""
New Release - My Book Live Firmware Version 02.43.09 - 038 (1/27/2015)
New Release - My Book Live Firmware Version 02.43.10 - 048 (6/22/2015)

Sample URL - http://download.wdc.com/nas/apnc-024310-048-20150622.deb
"""

logging.basicConfig()
log = logging.getLogger(__name__)
log.setLevel(int(os.getenv("DEBUG", logging.INFO)))

def _parsedate(s):
	return datetime.strptime(s, '%m/%d/%Y')

def countback(start=datetime.today(), days=60):
	dt = timedelta(1)
	current = start
	for c in count(1):
		if c == days+1:
			break
		yield current.strftime("%Y%m%d")
		current -= dt

def url(version, build, date):
	ctx = dict(ver=version.replace('.', ''), bld=build, dat=date)
	return "http://download.wdc.com/nas/apnc-%(ver)s-%(bld)s-%(dat)s.deb" % ctx

def probe(fmt, *combi):
	fmt = "http://download.wdc.com/nas/apnc-024309-038-201501%02d.deb"
	for s in product(*combi):
		url = fmt % s
		req = head(url)
		if req.status_code != 404:
			print url, req

	log.info("done")

def latest(page='http://www.wdc.com/wdproducts/updates/?family=wdfmb_live'):
	"""returns (version, build, date)"""
	# "<b>Firmware Version 02.43.10 - 048 (6/22/2015)</b>"
	eg = "<b>Firmware Version ([^ ]*) - ([0-9]*) \(([^\)]*)\)</b>"
	pattern = re.compile(eg)
	req = urlopen(page)
	n = count(1)
	for x in req:
		n.next()
		if 'Firmware Version' in x:
			mo = pattern.search(x)
			if mo:
				log.debug("ver=%s, bld=%s, date=%s", *mo.groups())
				return mo.group(1), mo.group(2), _parsedate(mo.group(3))

def poke(link):
	try:
		sc = urlopen(link).getcode()
		return sc >199 and sc <300	
	except HTTPError:
		return False
	return sc >199 and sc <300


def _backtrack():
	r = countback(datetime(2015, 1, 27), 60)
	for i, s in enumerate(r):
		link = url("024309", "038", s)
		print i+1, link, poke(link)

def _download(url):
	fn = url.split('/')[-1]
	with file(fn, 'w') as out:
		for x in urlopen(url):
			out.write(x)
		return fn

def discover(args):
	version, build, start, days = args
	r = countback(start, days)
	for i, s in enumerate(r):
		link = url(version, build, s)
		if poke(link):
			fn = _download(link)
			log.info("Process %d - %d: downloaded %s -> %s", os.getpid(), i, link, fn)

def distribute(poolsize, version, build, start, days):
	pool = Pool(poolsize)
	interval = int(days/poolsize) + 1
	args = []
	for offset in xrange(0, days+1, interval):
		delta = timedelta(offset)
		args.append((version, build, start-delta, interval))
	pool.map(discover, args)

if '__main__' == __name__:
	fwinfo = latest()
	if fwinfo:
		version, build, date = fwinfo
		distribute(5, version, build, date, 60)
