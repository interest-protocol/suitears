/*
* @title Fund
*
* @notice Tracks and calculates the number of shares proportionally with the underlying amount.  
*
* @dev It is a utility struct to easily know how many shares to issue/burn based on an underlying amount. 
*/
module suitears::fund {
  // === Imports === 

  use suitears::math128::{mul_div_down,  mul_div_up};

  // === Structs === 

  struct Fund has store, copy, drop {
    // The amount of shares issued based on the underlying amount.  
    shares: u128,
    // The amount of assets in the fund. 
    underlying: u128
  }

  // === Public Create Function ===  

  /*
  * @notice Creates an empty {Fund}.
  *
  * @return Fund.  
  */
  public fun empty(): Fund {
    Fund {
      shares: 0,
      underlying: 0
    }
  }

  // === Public View Functions ===    

  /*
  * @notice Returns the amount of underlying in the `self`.
  * 
  * @param self A {Fund}.  
  * @return u64. The amount of underlying.    
  */
  public fun underlying(self: &Fund): u64 {
    (self.underlying as u64)
  }

  /*
  * @notice Returns the amount of shares in the `self`.
  * 
  * @param self A {Fund}.  
  * @return u64. The amount of shares.    
  */
  public fun shares(self: &Fund): u64 {
    (self.shares as u64)
  }

  /*
  * @notice Returns the number of shares the `self` would issue if more `underlying` was deposited in it.
  * 
  * @param self A {Fund}.  
  * @param underlying The amount of underlying that the caller intends to add to the `self`.   
  * @param round_up If true we would round up the returned value.  
  * @return u64. The amount of shares the fund would issue.    
  */
  public fun to_shares(self: &Fund, underlying: u64, round_up: bool): u64 {
    if (self.underlying == 0) return underlying;
      
    if (round_up) {
      (mul_div_up((underlying as u128), self.shares, self.underlying) as u64)
    } else {
      (mul_div_down((underlying as u128), self.shares, self.underlying) as u64)
    } 
  }

  /*
  * @notice Returns the amount underlying the `self` would release if the `shares` amount were to be burned.
  * 
  * @param self A {Fund}.  
  * @param shares The amount of shares that the caller intends to burn.   
  * @param round_up If true we would round up the returned value.  
  * @return u64. The amount underlying the fund would release.    
  */
  public fun to_underlying(rebase: &Fund, shares: u64, round_up: bool): u64 {
    if (rebase.shares == 0) return shares;
    
    if (round_up) {
      (mul_div_up((shares as u128), rebase.underlying, rebase.shares) as u64)
    } else {
      (mul_div_down((shares as u128), rebase.underlying, rebase.shares) as u64)
    } 
  }

  // === Public Mutative Functions ===   

  /*
  * @notice Burns shares from the `self` and returns the correct `underlying` amount.
  * 
  * @dev This function reduces the amount of underlying and shares in the fund. 
  *
  * @param self A {Fund}.  
  * @param shares The amount of shares that the caller intends to burn.   
  * @param round_up If true we would round up the returned value.  
  * @return u64. The amount underlying the `shares` were worth.    
  */
  public fun sub_shares(self: &mut Fund, shares: u64, round_up: bool): u64 {
    let underlying = to_underlying(self, shares, round_up);
    self.underlying = self.underlying - (underlying as u128);
    self.shares = self.shares - (shares as u128);
    underlying
  }

  /*
  * @notice Adds `underlying` to the `self` and returns the additional shares issued.
  * 
  * @dev This function increases the amount of underlying and shares in the fund. 
  *
  * @param self A {Fund}.  
  * @param underlying The amount of underlying to deposit in the `self`.   
  * @param round_up If true we would round up the returned value.  
  * @return u64. The amount of shares the fund issued.    
  */
  public fun add_underlying(rebase: &mut Fund, underlying: u64, round_up: bool): u64 {
    let shares = to_shares(rebase, underlying, round_up);
    rebase.underlying = rebase.underlying + (underlying as u128);
    rebase.shares = rebase.shares + (shares as u128);
    shares
  }

  /*
  * @notice Removes `underlying` from the `self` and returns the burned shares.
  * 
  * @dev This function reduces the amount of underlying and shares in the fund. 
  *
  * @param self A {Fund}.  
  * @param underlying The amount of underlying to remove from the `self`.   
  * @param round_up If true we would round up the returned value.  
  * @return u64. The amount of shares the fund burned.    
  */
  public fun sub_underlying(rebase: &mut Fund, underlying: u64, round_up: bool): u64 {
    let shares = to_shares(rebase, underlying, round_up);
    rebase.underlying = rebase.underlying - (underlying as u128);
    rebase.shares = rebase.shares - (shares as u128);
    shares
  }

  /*
  * @notice Adds profits to the underlying. 
  * 
  * @dev This is to add profits to the fund.
  *
  * @param self A {Fund}.  
  * @param profit The amount of underlying to add as profit to `self.underlying`.     
  */
  public fun add_profit(rebase: &mut Fund, profit: u64) {
    rebase.underlying = rebase.underlying + (profit as u128);
  }  
}