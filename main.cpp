#include <iostream>
#include <cstdlib>

using namespace std;

extern "C" void f1(int programSize, int count, ...);

int main(int argc, char* argv[]) {
    if (argc < 4 || ((argc - 2) % 2 != 0)) {
        cerr << "Uso: " << argv[0]
             << " <tamanho-programa> <addr1> <size1> [<addr2> <size2> ...]" << endl;
        return 1;
    }
    
    int programSize = std::atoi(argv[1]);
    if (programSize <= 0) {
        cerr << "Erro: o tamanho do programa deve ser um inteiro positivo." << endl;
        return 1;
    }
    
    int count = (argc - 2) / 2;
    
    switch (count) {
        case 1:
            f1(programSize, count, std::atoi(argv[2]), std::atoi(argv[3]));
            break;
        case 2:
            f1(programSize, count,
               std::atoi(argv[2]), std::atoi(argv[3]),
               std::atoi(argv[4]), std::atoi(argv[5]));
            break;
        case 3:
            f1(programSize, count,
               std::atoi(argv[2]), std::atoi(argv[3]),
               std::atoi(argv[4]), std::atoi(argv[5]),
               std::atoi(argv[6]), std::atoi(argv[7]));
            break;
        case 4:
            f1(programSize, count,
               std::atoi(argv[2]), std::atoi(argv[3]),
               std::atoi(argv[4]), std::atoi(argv[5]),
               std::atoi(argv[6]), std::atoi(argv[7]),
               std::atoi(argv[8]), std::atoi(argv[9]));
            break;
        case 5:
            f1(programSize, count,
               std::atoi(argv[2]), std::atoi(argv[3]),
               std::atoi(argv[4]), std::atoi(argv[5]),
               std::atoi(argv[6]), std::atoi(argv[7]),
               std::atoi(argv[8]), std::atoi(argv[9]),
               std::atoi(argv[10]), std::atoi(argv[11]));
            break;
        default:
            cerr << "Numero de blocos nao suportado (maximo 5) neste exemplo." << endl;
            return 1;
    }
    
    return 0;
}
