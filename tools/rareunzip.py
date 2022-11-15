import sys
import zlib

def rzip_inflate(data):
    d = zlib.decompressobj(wbits=-15)
    res = d.decompress(data)
    return res

def main():
    with open(sys.argv[1], "rb") as f:
        with open(sys.argv[2], "wb") as o:
            data = f.read()
            data = data[2:]
            o.write(rzip_inflate(data))

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("usage %s infile outfile" % sys.argv[0])
    else:
        main()
