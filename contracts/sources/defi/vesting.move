/*
* @title Vesting
*
* @notice A utility module to provide virtual implementations of vesting schedules.
*/
module suitears::vesting {
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
}