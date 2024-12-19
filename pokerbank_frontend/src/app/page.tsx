"use client";

import { Button } from "@/components/ui/button";
import { Crown, HandCoins } from "lucide-react";

import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

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
  return (
    <div className="max-w-[60ch] mx-auto my-10 p-5">
      <ul className="[&_li:last-child]:border-0">
        {invoices.map((player) => (
          <li key={player.email} className="border-b py-2 px-1">
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
                  <p className="font-medium text-sm leading-none">
                    {player.name}
                    {player.isBank && (
                      <Crown
                        size="12"
                        color="#ca8a04"
                        className="ml-[0.4rem] inline-block -translate-y-[0.08rem]"
                      />
                    )}
                  </p>
                  <p className="text-xs text-muted-foreground leading-none">
                    {player.email}
                  </p>
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
                    <DialogContent
                      className="sm:max-w-[425px]"
                      key={player.name}
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
                            <Crown
                              size="16"
                              color="#ca8a04"
                              className="ml-[0.4rem] inline-block -translate-y-[0.08rem]"
                            />
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
                              <div className="text-sans text-sm text-muted-foreground">
                                {new Date(
                                  transaction.timestamp,
                                ).toLocaleTimeString()}
                              </div>
                              <div className="text-sm text-zinc-700">
                                {transaction.amount.toLocaleString("en-US", {
                                  style: "currency",
                                  currency: "USD",
                                })}
                              </div>
                            </li>
                          ))}
                        </ul>
                      </div>
                    </DialogContent>
                  </Dialog>
                </div>
              </div>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
