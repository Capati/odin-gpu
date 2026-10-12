import type { Metadata } from "next";
import ExampleBoot from "./ExampleBoot";
import { getExamples } from "../../../lib/examples";

export async function generateStaticParams() {
  // Live demos only; native-only examples (web: false) get no page.
  return getExamples()
    .filter((ex) => ex.web !== false)
    .map((ex) => ({ name: ex.name }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ name: string }>;
}): Promise<Metadata> {
  const { name } = await params;
  const ex = getExamples().find((e) => e.name === name);
  return {
    title: `${ex?.title ?? name} · odin-gpu examples`,
    icons: { icon: [{ url: "../../shared/favicon.ico" }] },
  };
}

export default async function ExamplePage({
  params,
}: {
  params: Promise<{ name: string }>;
}) {
  const { name } = await params;
  const ex = getExamples().find((e) => e.name === name);
  if (!ex) {
    return (
      <main className="mx-auto max-w-[1100px] px-5 py-10">
        <p>
          Unknown example. <a className="text-link hover:underline" href="../../">All examples</a>
        </p>
      </main>
    );
  }

  return (
    <>
      <script src="../../shared/third-party/stats.js" />
      <script src="../../shared/odin.js" />
      <script src="../../shared/webgpu.js" />
      <script src="../../shared/utils.js" />
      <div className="h-screen w-screen overflow-hidden">
        <ExampleBoot />
      </div>
    </>
  );
}
