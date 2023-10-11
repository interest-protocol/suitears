module suimate::wad_ray_math {

  const RAY: u256 = 1_000_000_000_000_000_000; // 1e18

  const WAD: u128 = 1_000_000_000; // 1e9

  public fun wad(): u128 {
    WAD
  }

  public fun ray(): u256 {
    RAY
  }  
}