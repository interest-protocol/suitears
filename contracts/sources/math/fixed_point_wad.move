// Fixed Point Math without a Type guard/wrapper  
// Wad has a higher accurate and assumes values have 18 decimals
module suitears::fixed_point_wad {
  use suitears::int::{Self, Int};
  use suitears::math256::{Self, pow, log2_down};

  const WAD: u256 = 1_000_000_000_000_000_000; // 1e18

  const EOverflow: u64 = 0;
  const EUndefined: u64 = 1;
  
  public fun wad(): u256 {
    WAD
  }

  public fun try_wad_mul_down(x: u256, y: u256): (bool, u256)  {
    math256::try_mul_div_down(x, y, WAD)
  }

  public fun try_wad_mul_up(x: u256, y: u256): (bool, u256)  {
    math256::try_mul_div_up(x, y, WAD) 
  }

  public fun try_wad_div_down(x: u256, y: u256): (bool, u256)  {
    math256::try_mul_div_down(x, WAD, y)
  }

  public fun try_wad_div_up(x: u256, y: u256): (bool, u256) {
    math256::try_mul_div_up(x, WAD, y)
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
    math256::mul_div_up(x, WAD, y)
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

    int::from_u256((int::to_u256(r) * 3822833074963236453042738258902158003155416615667) >> (195 - int::to_u8(k)))
  }

  public fun ln_wad(x: Int): Int {
    assert!(int::is_positive(x), EUndefined);

    let k = int::sub(int::from_u8(log2_down(int::to_u256(x))), int::from_u256(96));

    x = int::shl(x, (156 - int::to_u8(k)));
    x = int::neg_from_u256(int::to_u256(x) >> 159);

    let p = int::add(x, int::from_u256(3273285459638523848632254066296));
    p = int::add(int::shr(int::mul(p, x), 96), int::from_u256(24828157081833163892658089445524));
    p = int::add(int::shr(int::mul(p, x), 96), int::from_u256(43456485725739037958740375743393));
    p = int::sub(int::shr(int::mul(p, x), 96), int::from_u256(11111509109440967052023855526967));
    p = int::sub(int::shr(int::mul(p, x), 96), int::from_u256(45023709667254063763336534515857));
    p = int::sub(int::shr(int::mul(p, x), 96), int::from_u256(14706773417378608786704636184526));
    p = int::sub(int::mul(p, x), int::from_u256(795164235651350426258249787498 << 96));

    let q = int::add(x,int::from_u256(5573035233440673466300451813936));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(71694874799317883764090561454958));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(283447036172924575727196451306956));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(401686690394027663651624208769553));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(204048457590392012362485061816622));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(31853899698501571402653359427138));
    q = int::add(int::shr(int::mul(q, x), 96), int::from_u256(909429971244387300277376558375));

    let r = int::div(p, q);

    r = int::mul(r,int::from_u256(1677202110996718588342820967067443963516166));
    r = int::add(r, int::mul(int::from_u256(16597577552685614221487285958193947469193820559219878177908093499208371) , k));
    r = int::add(r, int::from_u256(600920179829731861736702779321621459595472258049074101567377883020018308));

    int::shr(r, 174)
  }

}