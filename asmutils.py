# Convert binary fraction to decimal fraction
def bin2float(s):
  t = s.split('.')
  return int(t[0], 2) + int(t[1], 2) / 2.**len(t[1])

# Convert 64-bit floating point register dump to decimal fraction
def doubleBinFloat2dec(s):
  signBit = int(s[0], 2)
  #print signBit
  exponent = int(s[1:12], 2)
  #print exponent
  mantissa = bin2float('1.' + s[12:])
  #print mantissa

  return (-1)**signBit * mantissa * 2**(exponent - 1023)
