import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 通用项目代码评估工具 (多维度拆分版)
 * 适配现代与传统 (Legacy) Java Web 结构。
 */
public class ProjectEstimator {

    // --- 精准模型配置 ---
    // 后端生产力基准 (逻辑密集型: Java, SQL)
    private static final double BE_LOW_BOUND = 80.0;
    private static final double BE_HIGH_BOUND = 120.0;
    private static final double BE_RECOMMENDED = 100.0;
    // 前端生产力基准 (UI/模板型: TSX, CSS 较快)
    private static final double FE_LOW_BOUND = 150.0;
    private static final double FE_HIGH_BOUND = 200.0;
    private static final double FE_RECOMMENDED = 175.0;
    private static final double COMPLEXITY_FACTOR = 1.2;

    // 分类扩展名 (加入 .jsp 适配传统项目)
    private static final List<String> FRONTEND_EXTS = Arrays.asList(".tsx", ".ts", ".css", ".scss", ".html", ".js", ".jsp");
    private static final List<String> BACKEND_EXTS = Arrays.asList(".java", ".sql", ".xml", ".properties", ".yml", ".yaml", ".gradle");

    // 代码权重配置
    private static final Map<String, Double> WEIGHTS = new HashMap<String, Double>() {{
        put(".java", 1.0); put(".tsx", 1.0); put(".ts", 1.0); put(".js", 1.0); put(".sql", 1.0); put(".jsp", 1.0);
        put(".xml", 0.5); put(".yml", 0.5); put(".yaml", 0.5); put(".gradle", 0.5); 
        put(".properties", 0.5); put(".css", 0.5); put(".scss", 0.5); put(".html", 0.5);
    }};

    // 严苛排除目录 (加入 classes 避免统计编译后的文件)
    private static final List<String> EXCLUDE_DIRS = Arrays.asList(
            "node_modules", ".next", ".git", ".vscode", "dist", "build", "out", "public",
            "target", "bin", ".gradle", ".idea", "classes", "WEB-INF/classes"
    );

    // 严苛排除后缀 (编译产物)
    private static final List<String> EXCLUDE_EXTS = Arrays.asList(".class", ".swf", ".jar", ".war", ".zip", ".lock");

    // 排除自动生成的锁文件 (行数庞大但非业务代码)
    private static final java.util.Set<String> EXCLUDE_NAMES = new java.util.HashSet<>(Arrays.asList(
            "pnpm-lock.yaml", "yarn.lock", "package-lock.json", "Gemfile.lock", "poetry.lock"
    ));

    private static long feRawLoc = 0, beRawLoc = 0;
    private static double feWeightedLoc = 0, beWeightedLoc = 0;
    private static long feFileCount = 0, beFileCount = 0;

    public static void main(String[] args) {
        System.out.println("\u001B[34m=== 通用项目代码评估工具 (前后端拆分版) ===\u001B[0m");
        String currentDir = System.getProperty("user.dir");
        System.out.println("\u001B[90m扫描目录: " + currentDir + "\u001B[0m");

        try {
            Path startPath = Paths.get(currentDir);
            Files.walkFileTree(startPath, new SimpleFileVisitor<Path>() {
                @Override
                public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) {
                    if (EXCLUDE_DIRS.contains(dir.getFileName().toString())) return FileVisitResult.SKIP_SUBTREE;
                    return FileVisitResult.CONTINUE;
                }

                @Override
                public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) {
                    String fileName = file.getFileName().toString();
                    String ext = "";
                    int i = fileName.lastIndexOf('.');
                    if (i > 0) ext = fileName.substring(i).toLowerCase();

                    if (EXCLUDE_EXTS.contains(ext)) return FileVisitResult.CONTINUE;
                    if (EXCLUDE_NAMES.contains(fileName)) return FileVisitResult.CONTINUE; // 过滤锁文件

                    if (WEIGHTS.containsKey(ext)) {
                        long lines = countLines(file.toFile());
                        if (FRONTEND_EXTS.contains(ext)) {
                            feRawLoc += lines;
                            feWeightedLoc += lines * WEIGHTS.get(ext);
                            feFileCount++;
                        } else if (BACKEND_EXTS.contains(ext)) {
                            beRawLoc += lines;
                            beWeightedLoc += lines * WEIGHTS.get(ext);
                            beFileCount++;
                        }
                    }
                    return FileVisitResult.CONTINUE;
                }
            });

            if (feRawLoc + beRawLoc == 0) {
                System.out.println("\u001B[33m警告: 未在当前路径及其子目录中找到匹配的源码文件。\u001B[0m");
                return;
            }

            displayCategory("前端 (Frontend)", feFileCount, feRawLoc, feWeightedLoc, FE_LOW_BOUND, FE_HIGH_BOUND);
            displayCategory("后端 (Backend)", beFileCount, beRawLoc, beWeightedLoc, BE_LOW_BOUND, BE_HIGH_BOUND);

            double feMin = (feWeightedLoc / FE_HIGH_BOUND) * COMPLEXITY_FACTOR;
            double feMax = (feWeightedLoc / FE_LOW_BOUND) * COMPLEXITY_FACTOR;
            double beMin = (beWeightedLoc / BE_HIGH_BOUND) * COMPLEXITY_FACTOR;
            double beMax = (beWeightedLoc / BE_LOW_BOUND) * COMPLEXITY_FACTOR;
            double mdRec = (feWeightedLoc / FE_RECOMMENDED + beWeightedLoc / BE_RECOMMENDED) * COMPLEXITY_FACTOR;

            System.out.println("\u001B[34m=== 总项目评估 ===\u001B[0m");
            System.out.printf("工作量区间: \u001B[32m%.1f - %.1f 人日\u001B[0m%n", feMin + beMin, feMax + beMax);
            System.out.printf("推荐参考值: \u001B[33m%.1f 人日\u001B[0m%n", mdRec);
            System.out.println("----------------------------------------");
            System.out.println("\u001B[90m(提示：具体使用建议请参考项目 README.md)\u001B[0m");

        } catch (IOException e) {
            System.err.println("\u001B[31m错误: " + e.getMessage() + "\u001B[0m");
        }
    }

    private static void displayCategory(String label, long count, long raw, double weighted, double lowBound, double highBound) {
        System.out.println("----------------------------------------");
        System.out.println(label + ":");
        System.out.printf("  文件数: %d | 原始 LOC: %d%n", count, raw);
        System.out.printf("  加权 LOC: \u001B[32m%d\u001B[0m%n", Math.round(weighted));
        if (weighted > 0) {
            double mdMin = (weighted / highBound) * COMPLEXITY_FACTOR;
            double mdMax = (weighted / lowBound) * COMPLEXITY_FACTOR;
            System.out.printf("  预估工作量: \u001B[33m%.1f - %.1f 人日\u001B[0m%n", mdMin, mdMax);
        }
    }

    private static long countLines(File file) {
        long lines = 0;
        try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
            while (reader.readLine() != null) lines++;
        } catch (IOException ignored) {}
        return lines;
    }
}
