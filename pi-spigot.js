// Original: https://github.com/NesHacker/NesPi/blob/main/pi-spigot.js
// Modified to output the highest value of each variable for 4800 digits.
// This helps test how many bits need to be allocated for each.

function toHex (number) {
  return `${number.toString(16).toUpperCase()}`
}

/**
 * JavaScript implementation of pi-spigot.
 * @see https://www.maa.org/sites/default/files/pdf/pubs/amm_supplements/Monthly_Reference_12.pdf
 * @param {number} n Number of digits to calculate.
 * @returns {string} A string containing `n` digits of pi.
 */
function piSpigot (n) {
  n += 1
  const len = (10*n / 3) | 0
  const A = []
  const digits = []

  for (let k = 0; k < len+1; k++) {
    A.push(2)
  }

  let nines = 0
  let predigit = 0

  let highestLeft = 0, highestRight = 0, highestQ = 0, highestZ = 0;

  for (let j = n; j >= 1; j--) {
    let q = 0
    let z = 0

    for (let i = len; i >= 1; i--) {

      let left = 10 * A[i]
      let right = q * i
      z = left + right

      if (left > highestLeft) highestLeft = left;
      if (right > highestRight) highestRight = right;
      if (q > highestQ) highestQ = q;
      if (z > highestZ) highestZ = z;

      let twoI = 2 * i
      let twoIMinusOne = twoI - 1

      A[i] = z % twoIMinusOne
      q = (z / twoIMinusOne) | 0

    }

    A[1] = q % 10
    q = (q / 10) | 0

    if (q == 9) {
      nines++
    } else if (q == 10) {
      digits.push(predigit + 1)
      for (let k = 1; k <= nines; k++) {
        digits.push(0)
      }
      predigit = 0
      nines = 0
    } else {
      digits.push(predigit)
      predigit = q
      //if (j == 6) console.log(predigit)
      if (nines != 0) {
        for (let k = 1; k <= nines; k++) {
          digits.push(9)
        }
        nines = 0
      }
    }


  }

  console.log("Highest left: " + highestLeft);
  console.log("Highest right: " + highestRight);
  console.log("Highest q: " + highestQ);
  console.log("Highest z: " + highestZ);

  //const checksum = toHex(digits.reduce((a, b) => a + b) % 0x100)
  //console.log('Checksum: ' + checksum)

  return digits[1] + '.' + digits.slice(2).join('')
}

piSpigot(4800)
