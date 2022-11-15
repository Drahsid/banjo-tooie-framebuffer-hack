import sys
import zlib

def roundup(num):
    return 0x10 * round(num / 0x10)

def rzip_inflate(data):
    d = zlib.decompressobj(wbits=-15)
    res = d.decompress(data)
    return res

def main():
    with open(sys.argv[1], "rb") as f:
        with open(sys.argv[2], "wb") as o:
            data = f.read()
            inflate = rzip_inflate(data)
            length = (roundup(len(inflate)) >> 4) & 0xFFFF
            data = length.to_bytes(length=2, byteorder='big', signed=False) + data
            o.write(data)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("usage %s infile outfile" % sys.argv[0])
    else:
        main()

