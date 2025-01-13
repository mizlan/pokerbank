import { Outlet } from "react-router";

export default function RootLayout() {
  return (
    <div className="max-w-2xl mx-auto">
      <Outlet />
    </div>
  );
}
