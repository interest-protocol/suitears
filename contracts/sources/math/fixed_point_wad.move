// Fixed Point Math without a Type guard/wrapper  
// Ray has a higher accurate and assumes values have 18 decimals
module suitears::fixed_point_wad {

  use suitears::int::{Self, Int};
  use suitears::math256::{Self, pow};

  const WAD: u256 = 1_000_000_000_000_000_000; // 1e18

  const EOverflow: u64 = 0;
  
  public fun wad(): u256 {
    WAD
  }

  public fun wad_mul_down(x: u256, y: u256): u256 {
    math256::mul_div_down(x, y, WAD)
  }

  public fun wad_mul_up(x: u256, y: u256): u256 {
    math256::mul_div_up(x, y, WAD) 
  }

  public fun wad_div_down(x: u256, y: u256): u256 {
    math256::mul_div_down(x, WAD, y)
  }

  public fun wad_div_up(x: u256, y: u256): u256 {
    math256::div_up(x * WAD, y)
  }

  public fun to_wad(x: u256, decimal_factor: u64): u256 {
    math256::mul_div_down(x, WAD, (decimal_factor as u256))
  }

  // * Credit to https://xn--2-umb.com/22/exp-ln/

  public fun exp_wad(x: Int): Int {
    if (int::lte(x, int::neg_from_u256(42139678854452767551))) return int::zero();

    assert!(int::lt(x, int::from_u256(135305999368893231589)), EOverflow);

    let x =   int::div(int::shl(x, 78), int::from_u256(pow(5, 18)));

    let k = int::shr(int::add(int::div(int::shl(x, 96), int::from_u256(54916777467707473351141471128)), int::from_u256(pow(2, 95))), 96);
    x = int::sub(x, k);

    let y = int::add(x, int::from_u256(1346386616545796478920950773328));
    y = int::add(int::shr(int::mul(y, x), 96), int::from_u256(57155421227552351082224309758442));
    let p = int::sub(int::add(y, x), int::from_u256(94201549194550492254356042504812));
    p = int::add(int::shr(int::mul(p, y), 96), int::from_u256(28719021644029726153956944680412240));
    p = int::add(int::mul(p, x), int::from_u256(4385272521454847904659076985693276 << 96));

    let q = int::sub(x, int::from_u256(2855989394907223263936484059900));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(50020603652535783019961831881945));
    q = int::sub(int::shr(int::mul(q, x), 96), int::from_u256(533845033583426703283633433725380));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(3604857256930695427073651918091429));
    q = int::sub(int::shr(int::mul(q, x), 96), int::from_u256(14423608567350463180887372962807573));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(26449188498355588339934803723976023));

    let r = int::div(p, q);

    int::from_u256((int::as_u256(r) * 3822833074963236453042738258902158003155416615667) >> (195 - int::as_u8(k)))
  }
}