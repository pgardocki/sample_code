# My code in this folder solves the game below:

## Custora's Job Queue Game
At Custora, we process a lot of data, calculating complex statistics from it as we go. Those statistics need to be calculated on demand, coming in an irregular pattern as users access the site, and they are also very heavy computations that can sometimes take a long time to compute.

To handle this system, we have a job queue that can add and remove machines dynamically based on demand. We want to process the jobs as quickly as possible, but each machine incurs a cost based on how long it runs, so we try to optimize for both speed and expense. The goal of this game is to process an imaginary queue of jobs as quickly and with as little cost as possible.

## The Basics

We've set up an API that you can access to get all of the data you need for your game. It is a turn-based game where each turn includes a batch of jobs that needs to be processed. For each turn you will be given the batch of jobs, and then you will create or remove machines as necessary and assign jobs to the machines for processing. Here are some basic ground rules:

1. There are two versions of the game, one with 500 turns and one with 50. Each turn contains between 1 and 40 jobs.

2. Each job requires a fixed amount of memory and a fixed number of turns to complete.

3. You can create machines whenever you want, and they are immediately available for jobs.

4. Each machine has 64GB of memory. If you assign greater than 64GB of jobs to a machine, the jobs will go on a queue for that machine and will be processed as memory is freed up in the order that they were assigned to the machine.

5. You can delete a machine whenever you want, but you will pay for it until all of its jobs, including the ones in its queue, have finished processing.

In general, a turn will look like this:

1. Pull the data for the turn, including its batch of jobs.

2. Create or remove machines as necessary to handle the new jobs.

3. Assign jobs to the machines for processing.

## Scoring

Each machine costs $1 per turn to operate. The goal is to process the jobs with as little delay as possible while incurring the minimum possible cost. By querying the game object, you will get two numbers that measure these values:

1. cost is the current total for the number of dollars spent.

2. delay_turns is the total number of turns between when jobs were given and when they started to execute.

The goal is to minimize these values. An approach that spins up a new machine for each job would have a delay_turns score of zero, but a very high cost. Alternatively, assigning all jobs to the same machine would give you a high value for both factors. The lowest possible value for delay_turns is zero, and we're not sure what the lowest possible cost is yet. We're less concerned with you getting perfect values for these things than with the organization of your code and your approach to the problem.
