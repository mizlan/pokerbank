"use client";

import { Button } from "@/components/ui/button";
import { Crown, HandCoins } from "lucide-react";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { AnimatePresence, motion } from "motion/react";
import Avatar from "boring-avatars";

import {
  randBetweenDate,
  randBoolean,
  randEmail,
  randFullName,
  randNumber,
} from "@ngneat/falso";

const generateRandomPlayerInfo = () => {
  const numTransactions = randNumber({ min: 1, max: 10 });
  const transactions = Array.from(Array(numTransactions).keys()).map(() => {
    return {
      amount: randNumber({ min: 100, max: 2000 }),
      timestamp: randBetweenDate({
        from: new Date("10/07/2020"),
        to: new Date(),
      }).toISOString(),
    };
  });
  return {
    email: randEmail(),
    name: randFullName(),
    totalAmount: randNumber({ min: 1000, max: 100000 }),
    isBank: randBoolean(),
    transactions,
  };
};

const invoices = Array.from(Array(randNumber({ min: 3, max: 20 })).keys()).map(
  () => {
    return generateRandomPlayerInfo();
  },
);

export default function Home() {
  const containerVariants = {
    hidden: {
      opacity: 0,
    },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.15,
      },
    },
  };

  const itemVariants = {
    hidden: {
      opacity: 0,
      y: 20,
    },
    visible: {
      opacity: 1,
      y: 0,
      transition: {
        duration: 0.4, //this controls the speed that the items in the list appear so if you want it to appear faster then decrease
        ease: "easeInOut",
      },
    },
  };
  return (
    <div className="max-w-[60ch] mx-auto my-10 p-5">
      <motion.ul
        className="[&_li:last-child]:border-0"
        variants={containerVariants}
        initial="hidden"
        animate="visible"
      >
        {invoices.map((player) => (
          <motion.li
            key={player.email}
            className="border-b py-2 px-1"
            variants={itemVariants}
          >
            <div className="flex justify-between">
              <div className="flex items-center gap-3">
                <Avatar
                  name={player.email}
                  colors={[
                    "#fbb498",
                    "#f8c681",
                    "#bec47e",
                    "#9bb78f",
                    "#98908d",
                  ]}
                  variant="beam"
                  size={32}
                />
                <div className="space-y-1">
                  <div className="font-medium text-sm leading-none">
                    {player.name}

                    {player.isBank && (
                      <TooltipProvider>
                        <Tooltip delayDuration={30}>
                          <TooltipTrigger asChild>
                            <Crown
                              size="12"
                              color="#ca8a04"
                              className="ml-[0.4rem] inline-block -translate-y-[0.08rem] cursor-pointer"
                            />
                          </TooltipTrigger>
                          <TooltipContent side="top" align="center">
                            Bank
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    )}
                  </div>
                  <div className="text-xs text-muted-foreground leading-none">
                    {player.email}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div
                  className="text-right font-mono text-zinc-700"
                  style={{ fontFeatureSettings: '"ss09" 1' }}
                >
                  {player.totalAmount.toLocaleString("en-US", {
                    style: "currency",
                    currency: "USD",
                  })}
                </div>
                <div className="text-right space-x-2">
                  <Dialog>
                    <DialogTrigger asChild>
                      <Button size="icon">
                        <HandCoins />
                      </Button>
                    </DialogTrigger>
                    <AnimatePresence>
                      <DialogContent
                        className="sm:max-w-[425px]"
                        key={player.name}
                      >
                        {/* two approaches: can remove the scales from initial and animate and only have opacity to have the fade in effect. 
                        or you can have the scale if you want it to expand as you open. design choice. increasing duration makes the transition
                        more dramatic and decreasing it makes the transition more subtle.
                        */}
                        <motion.div
                          initial={{ opacity: 0, scale: 0.9 }} // this scale controls how drastic you want the expand transition to be (decreasing-> more dramatic)
                          animate={{ opacity: 1, scale: 1 }}
                          exit={{ opacity: 0, scale: 0.9 }}
                          transition={{ duration: 0.2, ease: "easeInOut" }}
                        >
                          <DialogHeader className="items-center">
                            <Avatar
                              name={player.email}
                              colors={[
                                "#fbb498",
                                "#f8c681",
                                "#bec47e",
                                "#9bb78f",
                                "#98908d",
                              ]}
                              variant="beam"
                              size={62}
                            />
                            <DialogTitle>
                              {player.name}
                              {player.isBank && (
                                <TooltipProvider>
                                  <Tooltip delayDuration={30}>
                                    <TooltipTrigger asChild>
                                      <Crown
                                        size="16"
                                        color="#ca8a04"
                                        className="ml-[0.4rem] inline-block -translate-y-[0.08rem] cursor-pointer"
                                      />
                                    </TooltipTrigger>
                                    <TooltipContent side="top" align="center">
                                      Bank
                                    </TooltipContent>
                                  </Tooltip>
                                </TooltipProvider>
                              )}
                            </DialogTitle>
                          </DialogHeader>
                          <div className="py-4">
                            <ul
                              className="[&_li:last-child]:border-0 font-mono"
                              style={{ fontFeatureSettings: '"ss09" 1' }}
                            >
                              {player.transactions.map((transaction) => (
                                <li
                                  className="flex justify-between items-center gap-4 border-b py-2 px-1"
                                  key={transaction.timestamp}
                                >
                                  {/* option 2: original option: displays HH:MM and on hover HH:MM:SS */}

                                  <div className="relative group text-sans text-sm text-muted-foreground">
                                    <TooltipProvider>
                                      <Tooltip delayDuration={30}>
                                        <TooltipTrigger asChild>
                                          <span className="text-sans text-sm text-muted-foreground">
                                            {new Date(
                                              transaction.timestamp,
                                            ).toLocaleTimeString([], {
                                              hour: "2-digit",
                                              minute: "2-digit",
                                            })}
                                          </span>
                                        </TooltipTrigger>
                                        <TooltipContent
                                          side="top"
                                          align="center"
                                        >
                                          {
                                            new Date(
                                              transaction.timestamp,
                                            ).toLocaleTimeString([], {
                                              hour: "2-digit",
                                              minute: "2-digit",
                                              second: "2-digit",
                                            })
                                            // .replace(" AM", "")
                                            // .replace(" PM", "")
                                          }
                                        </TooltipContent>
                                      </Tooltip>
                                    </TooltipProvider>
                                    {/* option 2.25: original option: displays HH:MM WITHOUT AM/PM and on hover HH:MM:SS */}
                                    {/* <div className="relative group text-sans text-sm text-muted-foreground">
                                    {new Date(
                                      transaction.timestamp,
                                    ).toLocaleTimeString([], {
                                      hour: "2-digit",
                                      minute: "2-digit",
                                    })}
                                    <div
                                      className="absolute left-1/2 -translate-x-1/2 bottom-full mb-1 hidden group-hover:block px-2 py-1 bg-black text-white text-xs rounded"
                                      style={{ whiteSpace: "nowrap" }}
                                    >
                                      {new Date(transaction.timestamp)
                                        .toLocaleTimeString([], {
                                          hour: "2-digit",
                                          minute: "2-digit",
                                          second: "2-digit",
                                        })}
                                    </div> */}

                                    {/* option 2.5: original option: displays HH:MM WITHOUT AM/PM and on hover HH:MM:SS */}

                                    {/* <div className="relative group text-sans text-sm text-muted-foreground">
                                    {new Date(transaction.timestamp)
                                      .toLocaleTimeString([], {
                                        hour: "2-digit",
                                        minute: "2-digit",
                                      })
                                      .replace(" AM", "")
                                      .replace(" PM", "")}
                                    <div
                                      className="absolute left-1/2 -translate-x-1/2 bottom-full mb-1 hidden group-hover:block px-2 py-1 bg-black text-white text-xs rounded"
                                      style={{ whiteSpace: "nowrap" }}
                                    >
                                      {new Date(
                                        transaction.timestamp,
                                      ).toLocaleTimeString([], {
                                        hour: "2-digit",
                                        minute: "2-digit",
                                        second: "2-digit",
                                      })}
                                    </div> */}
                                  </div>

                                  <div className="text-sm text-zinc-700">
                                    {transaction.amount.toLocaleString(
                                      "en-US",
                                      {
                                        style: "currency",
                                        currency: "USD",
                                      },
                                    )}
                                  </div>

                                  {/* option: have the transactions negative or positive and if it's negative display in red 
                                  if it's positive display in green. 
                                  pros: clarity
                                  cons: more colors on the screen whereas the gray was clean
                                  
                                  note: make sure to change the min for transaction amount to a negative number to test 
                                  */}
                                  {/* <div
                                    className={`text-sm font-mono ${
                                      transaction.amount < 0
                                        ? "text-red-500"
                                        : "text-green-500"
                                    }`}
                                  >
                                    {transaction.amount.toLocaleString(
                                      "en-US",
                                      {
                                        style: "currency",
                                        currency: "USD",
                                      },
                                    )}
                                  </div> */}
                                </li>
                              ))}
                            </ul>
                          </div>
                        </motion.div>
                      </DialogContent>
                    </AnimatePresence>
                  </Dialog>
                </div>
              </div>
            </div>
          </motion.li>
        ))}
      </motion.ul>
    </div>
  );
}
