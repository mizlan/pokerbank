// import { useAuthStore } from "@/store";
// import { useEffect } from "react";
// import { useNavigate } from "react-router";
import useSWR from "swr";

function App() {
  // let navigate = useNavigate();

  const { data, error, isLoading } = useSWR("/api/session_info");

  if (isLoading) {
    return <p>isloding</p>;
  }

  if (error) {
    console.log("epic fail");
    return <p>{JSON.stringify(error)}</p>;
  }

  return (
    <div>
      <p>data</p>
      <p>{JSON.stringify(data)}</p>
    </div>
  );
}

export default App;
