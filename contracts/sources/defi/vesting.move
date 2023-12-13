/*
* @title Vesting
*
* @notice A utility module to provide virtual implementations of vesting schedules.
*/
module suitears::vesting {
  // === Imports ===  

  use sui::math;

  // === Constants ===   

  // @dev Represents 1 unit with 0 decimals - 1e9.
  const ROLL: u64 = 1_000_000_000; 

  // === Public Functions ===    

  /*
  * @notice Calculates the amount that has already vested.  
  *
  * @param start The beginning of the vesting schedule.  
  * @param duration The duration of the schedule.  
  * @param balance The current amount of tokens in the wallet.   
  * @param already_released The total amount of tokens released.  
  * @param timestamp The current time in milliseconds.  
  * @return u64. The vested amount.  
  */
  public fun linear_vested_amount(start: u64, duration: u64, balance: u64, already_released: u64, timestamp: u64): u64 {
    linear_vesting_schedule(start, duration, balance + already_released, timestamp)
  }

  /*
  * @notice Virtual implementation of a quadratic vesting formula - ax^2 + bx + c.  
  *
  * @dev The params `a`, `b` and `c` have a precision of `ROLL`. 
  *
  * @param a The a in ax^2 + bx + c. 
  * @param b The b in ax^2 + bx + c. 
  * @param c The c in ax^2 + bx + c. 
  * @param start The beginning of the vesting schedule.
  * @param cliff Waiting period until the release of tokens start.
  * @param duration The duration of the schedule.  
  * @param balance The current amount of tokens in the wallet.   
  * @param already_released The total amount of tokens released.  
  * @param timestamp The current time in milliseconds.  
  * @return u64. This returns the amount vested, as a function of time, for an asset given its total historical allocation.  
  */ 
  public fun quadratic_vested_amount(
    a: u64, 
    b: u64, 
    c: u64, 
    start: u64, 
    cliff: u64, 
    duration: u64, 
    balance: u64, 
    already_released: u64, 
    timestamp: u64
  ): u64   {
    quadratic_vesting_schedule(a, b, c, start, cliff, duration, balance + already_released, timestamp)
  } 

  // === Private Functions ===      

  /*
  * @notice Virtual implementation of a linear vesting formula.  
  *
  * @param start The beginning of the vesting schedule.  
  * @param duration The duration of the schedule.  
  * @param total_allocation The total amount of tokens since the beginning.  
  * @param timestamp The current time in milliseconds.  
  * @return u64. This returns the amount vested, as a function of time, for an asset given its total historical allocation.  
  */ 
  fun linear_vesting_schedule(start: u64, duration: u64, total_allocation: u64, timestamp: u64): u64 {
    if (timestamp < start) return 0;
    if (timestamp > start + duration) return total_allocation;
    (total_allocation * (timestamp - start)) / duration
  }

  /*
  * @notice Virtual implementation of a quadratic vesting formula.  
  *
  * @dev The params `a`, `b` and `c` have a precision of `ROLL`. 
  *
  * @param a The a in ax^2 + bx + c. 
  * @param b The b in ax^2 + bx + c. 
  * @param c The c in ax^2 + bx + c. 
  * @param start The beginning of the vesting schedule.
  * @param cliff Waiting period until the release of tokens start.
  * @param duration The duration of the schedule.  
  * @param total_allocation The total amount of tokens since the beginning.  
  * @param timestamp The current time in milliseconds.  
  * @return u64. This returns the amount vested, as a function of time, for an asset given its total historical allocation.  
  */ 
  fun quadratic_vesting_schedule(a: u64, b: u64, c: u64, start: u64, cliff: u64, duration: u64, total_allocation: u64, timestamp: u64): u64 {
    let time_delta = timestamp - start;
    if (time_delta < cliff) return 0;
    if (time_delta >= duration) return total_allocation;
    let progress = time_delta * ROLL / duration;

    let vested_proportion = quadratic(progress, a, b, c);

    if (vested_proportion <= 0) return 0;
    if (vested_proportion >= ROLL) return total_allocation;

    total_allocation * vested_proportion / ROLL
  }

  /*
  * @notice Virtual implementation of  ax^2 + bx + c.  
  *
  * @dev The params `a`, `b` and `c` have a precision of `ROLL`. 
  *
  * @param x The x in ax^2 + bx + c. 
  * @param a The a in ax^2 + bx + c. 
  * @param b The b in ax^2 + bx + c. 
  * @param c The c in ax^2 + bx + c. 
  * @return u64. result of ax^2 + bx + c. 
  */ 
  fun quadratic(x: u64, a: u64, b: u64, c: u64): u64 {
    math::pow(x, 2) / ROLL * a / ROLL 
    + (b * x / ROLL)
    + c
  }    
}